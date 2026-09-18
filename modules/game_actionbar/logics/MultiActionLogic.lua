-- chunkname: @/game_actionbar/logics/MultiActionLogic.lua

local AB = modules.game_actionbar
local multiPanel, multiPanelPositionEvent
local cacheMultiActionSlots = {}
local spellCooldownCache = {}
local spellGroupCooldownCache = {}
local itemMultiUseCooldownCache, multiActionSyncEvent
local MULTI_ITEM_CD_KEY = "itemShared"

local function readItemMultiUseCooldownRemaining()
	if not itemMultiUseCooldownCache then
		return 0
	end

	return math.max(0, itemMultiUseCooldownCache.startTime + itemMultiUseCooldownCache.exhaustion - g_clock.millis())
end

local function multiActionsEmpty(multiActions)
	if not multiActions then
		return true
	end

	for i = 1, 3 do
		local data = multiActions[i]

		if data and not table.empty(data) then
			return false
		end
	end

	return true
end

local function ensureSlotMultiActions(slot)
	if not slot.multiActions then
		slot.multiActions = {
			{},
			{},
			{}
		}
	end

	return slot.multiActions
end

local MULTI_ICON_SOURCE = "/assets/images/game/actionbar/marker-multiactionbutton"
local MULTI_ICON_SIZE = {
	width = 5,
	height = 11
}

local function applyMultiIconLayout(icon)
	if not icon or icon:isDestroyed() then
		return
	end

	icon:setSize(MULTI_ICON_SIZE)
	icon:setImageSource(MULTI_ICON_SOURCE)
	icon:setImageSize(MULTI_ICON_SIZE)
	icon:breakAnchors()
	icon:addAnchor(AnchorTop, "parent", AnchorTop)
	icon:addAnchor(AnchorLeft, "parent", AnchorLeft)
	icon:setMarginLeft(1)
	icon:setMarginTop(1)
	icon:setPhantom(true)
	icon:setFocusable(false)
end

local function ensureMultiIconWidget(slot)
	if not slot or slot:isDestroyed() then
		return nil
	end

	local icon = slot:getChildById("multiIcon")

	if icon and not icon:isDestroyed() then
		applyMultiIconLayout(icon)

		return icon
	end

	icon = g_ui.createWidget("UIWidget", slot)

	icon:setId("multiIcon")
	applyMultiIconLayout(icon)
	icon:setVisible(false)

	return icon
end

local function shouldShowMultiIcon(slot)
	if not slot then
		return false
	end

	if slot._multiPanelOpen then
		return true
	end

	return slot.multiActions ~= nil
end

local function setMultiIconVisible(slot, visible)
	if not slot then
		return
	end

	local icon = ensureMultiIconWidget(slot)

	if not icon then
		return
	end

	local show = visible and shouldShowMultiIcon(slot)

	icon:setVisible(show)

	if show then
		if raiseMultiActionMarkerAboveCooldown then
			raiseMultiActionMarkerAboveCooldown(slot)
		elseif icon.raise then
			icon:raise()
		end
	end
end

local function registerMultiActionSlot(slot)
	if not slot or multiActionsEmpty(slot.multiActions) then
		return
	end

	for _, s in ipairs(cacheMultiActionSlots) do
		if s == slot then
			return
		end
	end

	cacheMultiActionSlots[#cacheMultiActionSlots + 1] = slot

	ensureMultiActionSyncTick()
end

local function unregisterMultiActionSlot(slot)
	for i, s in ipairs(cacheMultiActionSlots) do
		if s == slot then
			table.remove(cacheMultiActionSlots, i)

			if #cacheMultiActionSlots == 0 then
				stopMultiActionSyncTick()
			end

			return
		end
	end
end

local function shouldShowMultiActionGraphicalCooldown()
	if not modules.client_options or not modules.client_options.getOption then
		return true
	end

	return modules.client_options.getOption("graphicalCooldown") ~= false
end

local function clearSubSlotProgressWidgets(subSlot)
	if not subSlot then
		return
	end

	for _, ch in pairs(subSlot:getChildren()) do
		local cid = ch:getId()

		if cid and tostring(cid):sub(1, 8) == "progress" then
			if ch.event then
				removeEvent(ch.event)

				ch.event = nil
			end

			ch:destroy()
		end
	end
end

local function refreshMultiSubSlotCooldownDisplay(subSlot, data, onlyIfMissing)
	if not subSlot or subSlot:isDestroyed() or not data or table.empty(data) then
		return
	end

	if not shouldShowMultiActionGraphicalCooldown() then
		clearSubSlotProgressWidgets(subSlot)

		return
	end

	local remaining, progressId, useGroupCooldown, groupId, spellId

	if data.words then
		local spell = Spells.getSpellByWords(data.words)

		if not spell or not getMultiActionCooldownRemaining then
			clearSubSlotProgressWidgets(subSlot)

			return
		end

		local spellRem, groupRem = getMultiActionCooldownRemaining(spell)

		remaining = math.max(spellRem, groupRem)

		if remaining <= 0 then
			clearSubSlotProgressWidgets(subSlot)

			return
		end

		useGroupCooldown = spellRem < groupRem

		if useGroupCooldown then
			groupId = getMultiActionActiveGroupId and getMultiActionActiveGroupId(spell)

			if not groupId then
				clearSubSlotProgressWidgets(subSlot)

				return
			end

			progressId = "progress" .. groupId
		else
			spellId = spell.id
			progressId = "progress" .. spellId
		end
	elseif data.itemId and data.itemId > 0 then
		local runeSpell = AB.getRuneUsageSpell(data.itemId)

		if runeSpell and getMultiActionCooldownRemaining then
			local spellRem, groupRem = getMultiActionCooldownRemaining(runeSpell)

			remaining = math.max(spellRem, groupRem)

			if remaining <= 0 then
				clearSubSlotProgressWidgets(subSlot)

				return
			end

			useGroupCooldown = spellRem < groupRem

			if useGroupCooldown then
				groupId = getMultiActionActiveGroupId and getMultiActionActiveGroupId(runeSpell)

				if not groupId then
					clearSubSlotProgressWidgets(subSlot)

					return
				end

				progressId = "progress" .. groupId
			else
				spellId = runeSpell.id
				progressId = "progress" .. spellId
			end
		else
			remaining = readItemMultiUseCooldownRemaining()

			if remaining <= 0 then
				clearSubSlotProgressWidgets(subSlot)

				return
			end

			progressId = "progress" .. MULTI_ITEM_CD_KEY
			groupId = MULTI_ITEM_CD_KEY
			useGroupCooldown = true
		end
	else
		clearSubSlotProgressWidgets(subSlot)

		return
	end

	if onlyIfMissing and progressId and subSlot:recursiveGetChildById(progressId) then
		return
	end

	clearSubSlotProgressWidgets(subSlot)

	local progressRect = g_ui.createWidget("ActionBarCooldownProgress", subSlot)

	progressRect:setId(progressId)

	progressRect.item = subSlot.parentSlot or subSlot

	if layoutActionBarCooldownProgress then
		layoutActionBarCooldownProgress(progressRect)
	end

	progressRect:show()

	local totalDuration, remainingMs = remaining, remaining

	if groupId == MULTI_ITEM_CD_KEY and getMultiActionItemCooldownTiming then
		totalDuration, remainingMs = getMultiActionItemCooldownTiming()
	else
		local spellData = data.words and Spells.getSpellByWords(data.words) or data.itemId and AB.getRuneUsageSpell(data.itemId)

		if spellData then
			if useGroupCooldown and getMultiActionGroupCooldownTiming then
				totalDuration, remainingMs = getMultiActionGroupCooldownTiming(spellData)
			elseif getMultiActionSpellCooldownTiming then
				totalDuration, remainingMs = getMultiActionSpellCooldownTiming(spellData.id)
			end
		end
	end

	local tickCount = 0

	if resolveCooldownProgressState then
		local _, _, count, percent = resolveCooldownProgressState(totalDuration, remainingMs)

		tickCount = count

		progressRect:setPercent(percent)
	else
		progressRect:setPercent(0)
	end

	multiActionCooldownSyncLock = true

	if useGroupCooldown and groupId and updateGroupCooldown then
		updateGroupCooldown(progressRect, totalDuration, groupId, tickCount)
	elseif spellId and updateCooldown then
		updateCooldown(progressRect, totalDuration, spellId, tickCount)
	end

	multiActionCooldownSyncLock = false
end

local function tickMultiActionSync()
	multiActionSyncEvent = nil

	for _, slot in ipairs(cacheMultiActionSlots) do
		if slot and not slot:isDestroyed() then
			AB.syncMultiActionSlot(slot)
		end
	end

	if #cacheMultiActionSlots > 0 then
		multiActionSyncEvent = scheduleEvent(tickMultiActionSync, 100)
	end
end

function ensureMultiActionSyncTick()
	if multiActionSyncEvent or #cacheMultiActionSlots == 0 then
		return
	end

	multiActionSyncEvent = scheduleEvent(tickMultiActionSync, 100)
end

function stopMultiActionSyncTick()
	if multiActionSyncEvent then
		removeEvent(multiActionSyncEvent)

		multiActionSyncEvent = nil
	end
end

function AB.syncMultiActionSlot(slot)
	if not slot or slot:isDestroyed() then
		return
	end

	AB.updateMultiSlotState(slot, true)

	if multiPanel and not multiPanel:isDestroyed() and multiPanel.parentSlot == slot then
		AB.refreshMultiActionPanel(slot)
		AB.refreshMultiActionPanelCooldowns(slot, true)
	end
end

local function hasActiveSpellCooldown(spellId)
	local cooldownData = spellCooldownCache[spellId]

	if cooldownData and cooldownData.startTime + cooldownData.exhaustion > g_clock.millis() then
		return true
	end

	return false
end

local function getSpellGroupCooldownRemaining(spellData)
	if not spellData or not spellData.group then
		return 0
	end

	local groupIds = Spells.getGroupIds(spellData)

	if not groupIds then
		return 0
	end

	local maxRemaining = 0

	for _, groupId in pairs(groupIds) do
		local groupCooldown = spellGroupCooldownCache[groupId]

		if groupCooldown then
			local remaining = groupCooldown.startTime + groupCooldown.exhaustion - g_clock.millis()

			if remaining > 0 and maxRemaining < remaining then
				maxRemaining = remaining
			end
		end
	end

	return maxRemaining
end

local function hasActiveGroupCooldown(spellData)
	return getSpellGroupCooldownRemaining(spellData) > 0
end

local function getActiveGroupCooldownId(spellData)
	if not spellData or not spellData.group then
		return nil
	end

	local groupIds = Spells.getGroupIds(spellData)

	if not groupIds then
		return nil
	end

	local bestId, bestRem = nil, 0

	for _, groupId in pairs(groupIds) do
		local groupCooldown = spellGroupCooldownCache[groupId]

		if groupCooldown then
			local remaining = groupCooldown.startTime + groupCooldown.exhaustion - g_clock.millis()

			if bestRem < remaining then
				bestRem = remaining
				bestId = groupId
			end
		end
	end

	return bestId
end

function AB.getSpellCooldownTiming(spellId)
	local cd = spellCooldownCache[spellId]

	if not cd or cd.exhaustion <= 0 then
		return nil, 0
	end

	local remaining = math.max(0, cd.startTime + cd.exhaustion - g_clock.millis())

	return cd.exhaustion, remaining
end

function AB.getGroupCooldownTiming(spellData)
	local groupId = getActiveGroupCooldownId(spellData)

	if not groupId then
		return nil, 0
	end

	local cd = spellGroupCooldownCache[groupId]

	if not cd or cd.exhaustion <= 0 then
		return nil, 0
	end

	local remaining = math.max(0, cd.startTime + cd.exhaustion - g_clock.millis())

	return cd.exhaustion, remaining
end

function AB.getItemMultiUseCooldownRemaining()
	return readItemMultiUseCooldownRemaining()
end

function AB.clearItemMultiUseCooldownCache()
	itemMultiUseCooldownCache = nil
end

function AB.getItemMultiUseCooldownTiming()
	if not itemMultiUseCooldownCache or itemMultiUseCooldownCache.exhaustion <= 0 then
		return nil, 0
	end

	return itemMultiUseCooldownCache.exhaustion, readItemMultiUseCooldownRemaining()
end

function AB.getMultiActionCooldownRemaining(spellData)
	if not spellData then
		return 0, 0
	end

	local spellRem = 0
	local cd = spellCooldownCache[spellData.id]

	if cd then
		spellRem = math.max(0, cd.startTime + cd.exhaustion - g_clock.millis())
	end

	return spellRem, getSpellGroupCooldownRemaining(spellData)
end

function AB.getMultiActionActiveGroupId(spellData)
	return getActiveGroupCooldownId(spellData)
end

local function multiActionEntryItemTier(data)
	if g_game.getFeature(GameThingUpgradeClassification) then
		local stored = data and data.getTier

		if type(stored) == "number" then
			return stored
		end
	end

	return 0
end

local function playerCanUseSpellForMulti(spellData)
	if not spellData then
		return false
	end

	if canUseSpell and not canUseSpell(spellData) then
		return false
	end

	local player = g_game.getLocalPlayer()

	if not player then
		return true
	end

	if spellData.mana and player:getMana() < spellData.mana then
		return false
	end

	if spellData.level and player:getLevel() < spellData.level then
		return false
	end

	if spellData.soul and player:getSoul() < spellData.soul then
		return false
	end

	if spellData.vocations and not table.contains(spellData.vocations, translateVocation(player:getVocation())) then
		return false
	end

	return true
end

local function playerCanUseRuneItemForMulti(runeSpell)
	return runeSpell ~= nil
end

function AB.getRuneUsageSpell(itemId)
	if not itemId or itemId <= 0 then
		return nil
	end

	if Spells.getRuneUsageSpell then
		return Spells.getRuneUsageSpell(itemId)
	end

	local runeData = SpellRunesData and SpellRunesData[itemId] or nil

	if not runeData then
		return nil
	end

	local groupCd = runeData.groupExhaustion or runeData.exhaustion
	local conjureSpell = Spells.getSpellDataById and Spells.getSpellDataById(runeData.id) or nil

	return {
		type = "Rune",
		id = runeData.id,
		name = conjureSpell and conjureSpell.name or runeData.name,
		icon = conjureSpell and conjureSpell.icon or nil,
		clientId = conjureSpell and conjureSpell.clientId or nil,
		group = {
			[runeData.group] = groupCd
		},
		exhaustion = runeData.exhaustion,
		_conjureVocations = conjureSpell and conjureSpell.vocations or nil
	}
end

local function evaluateMultiActionEntry(data)
	if not data or table.empty(data) then
		return "none"
	end

	local player = g_game.getLocalPlayer()

	if data.words then
		local spell = Spells.getSpellByWords(data.words)

		if not spell or not playerCanUseSpellForMulti(spell) then
			return "none"
		end

		if hasActiveSpellCooldown(spell.id) or hasActiveGroupCooldown(spell) then
			return "cooldown"
		end

		return "ready"
	end

	if data.itemId and data.itemId > 0 then
		if data.useType == "equip" then
			return "none"
		end

		if not player then
			return "ready"
		end

		local tier = multiActionEntryItemTier(data)

		if player:getInventoryCount(data.itemId, tier) <= 0 then
			return "none"
		end

		local runeSpell = AB.getRuneUsageSpell(data.itemId)

		if runeSpell then
			if not playerCanUseRuneItemForMulti(runeSpell) then
				return "none"
			end

			if hasActiveSpellCooldown(runeSpell.id) or hasActiveGroupCooldown(runeSpell) then
				return "cooldown"
			end

			if readItemMultiUseCooldownRemaining() > 0 then
				return "cooldown"
			end

			return "ready"
		end

		if readItemMultiUseCooldownRemaining() > 0 then
			return "cooldown"
		end

		return "ready"
	end

	if data.text and data.text ~= "" then
		return "ready"
	end

	return "none"
end

local function getMultiActionEntryCooldownRemaining(data)
	if not data or table.empty(data) then
		return 0
	end

	if data.words then
		local spell = Spells.getSpellByWords(data.words)

		if not spell then
			return 0
		end

		local spellRem, groupRem = AB.getMultiActionCooldownRemaining(spell)

		return math.max(spellRem or 0, groupRem or 0)
	end

	if data.itemId and data.itemId > 0 then
		local runeSpell = AB.getRuneUsageSpell(data.itemId)
		local itemUseRem = readItemMultiUseCooldownRemaining() or 0

		if runeSpell then
			local spellRem, groupRem = AB.getMultiActionCooldownRemaining(runeSpell)

			return math.max(spellRem or 0, groupRem or 0, itemUseRem)
		end

		return itemUseRem
	end

	return 0
end

local function resolveActiveSlot(multiActions)
	if multiActionsEmpty(multiActions) then
		return nil, nil, "none"
	end

	for i = 1, 3 do
		local data = multiActions[i]

		if data and not table.empty(data) and evaluateMultiActionEntry(data) == "ready" then
			return i, data, "ready"
		end
	end

	local bestIdx, bestData, bestRem

	for i = 1, 3 do
		local data = multiActions[i]

		if data and not table.empty(data) and evaluateMultiActionEntry(data) == "cooldown" then
			local rem = getMultiActionEntryCooldownRemaining(data)

			if not bestData or rem < bestRem then
				bestIdx, bestData, bestRem = i, data, rem
			end
		end
	end

	if bestData then
		return bestIdx, bestData, "cooldown"
	end

	for i = 1, 3 do
		local data = multiActions[i]

		if data and not table.empty(data) then
			return i, data, "none"
		end
	end

	return nil, nil, "none"
end

local function findNextAvailableAction(multiActions)
	local _, data = resolveActiveSlot(multiActions)

	return data
end

local function findNextDisplayAction(multiActions)
	local _, data = resolveActiveSlot(multiActions)

	return data
end

local function findNextExecutableAction(multiActions)
	local _, data = resolveActiveSlot(multiActions)

	return data
end

local function multiActionItemSlotMatches(slot, action)
	if not action or not action.itemId or action.itemId <= 0 then
		return false
	end

	return slot.itemId == action.itemId and slot.useType == action.useType and (slot.subType or -1) == (action.subType or -1) and (slot.getTier or 0) == (action.getTier or 0)
end

local function actionMatchesSlotDisplay(slot, action)
	if not slot or not action or table.empty(action) then
		return false
	end

	if action.words then
		if not slot.words or slot.words ~= action.words then
			return false
		end

		return (slot.parameter or "") == (action.parameter or "")
	end

	if action.itemId and action.itemId > 0 then
		if action.words or action.text then
			return false
		end

		if slot.words or slot.text and slot.text ~= "" then
			return false
		end

		return multiActionItemSlotMatches(slot, action)
	end

	if action.text and action.text ~= "" then
		if slot.words then
			return false
		end

		return slot.text == action.text
	end

	return false
end

function AB.shouldPaintItemMultiCdOnMainSlot(slot)
	if not slot or not slot.multiActions or multiActionsEmpty(slot.multiActions) then
		return true
	end

	local action = findNextDisplayAction(slot.multiActions)

	if not action then
		return false
	end

	if action.words then
		return false
	end

	if action.itemId and action.itemId > 0 then
		return multiActionItemSlotMatches(slot, action)
	end

	return false
end

local function clearSlotDisplayFields(slot)
	local icon = slot:getChildById("spellIcon")

	if icon then
		icon:hide()
		icon:setImageSource("")
	end

	if slot.clearItem then
		slot:clearItem()
	end

	slot:setText("")

	slot.itemId = nil
	slot.subType = nil
	slot.words = nil
	slot.text = nil
	slot.useType = nil
	slot.getTier = nil
	slot.passiveId = nil
	slot.parameter = nil
	slot.autoSend = nil
	slot.smartMode = nil
	slot.smartBaseItemId = nil
	slot._smartEquipPending = nil

	local txt = slot:getChildById("text")

	if txt then
		txt:setText("")
	end

	local countLbl = slot:getChildById("count")

	if countLbl then
		countLbl:setVisible(false)
		countLbl:setText("")
	end

	local tier = slot:getChildById("tier")

	if tier then
		tier:setVisible(false)
	end

	local spellParam = slot:getChildById("spellParameter")

	if spellParam then
		spellParam:setVisible(false)
		spellParam:setText("")
	end
end

local function applyActionDataToSlot(slot, data)
	if not data or table.empty(data) then
		return false
	end

	if clearSlotProgressWidgets then
		clearSlotProgressWidgets(slot)
	end

	clearSlotDisplayFields(slot)

	local applied = false

	if data.words then
		slot.words = data.words
		slot.parameter = data.parameter
		slot.autoSend = data.autoSend
		slot.itemId = 469

		slot:setItemId(469)
		AB.loadSpell(slot)

		applied = true
	elseif data.text then
		slot.text = data.text
		slot.autoSend = data.autoSend
		slot.itemId = 469

		slot:setItemId(469)
		AB.loadText(slot)

		applied = true
	elseif data.itemId and data.itemId > 0 then
		slot.itemId = data.itemId
		slot.subType = data.subType
		slot.useType = data.useType
		slot.getTier = data.getTier
		slot.smartMode = data.smartMode
		slot.smartBaseItemId = data.smartBaseItemId

		AB.loadObject(slot)

		applied = true
	end

	if applied and refreshMultiActionSlotCooldownDisplay then
		refreshMultiActionSlotCooldownDisplay(slot, false)
	end

	return applied
end

local function getMultiEntryCooldownOverlay(data)
	if not data or table.empty(data) or not getMultiActionCooldownRemaining then
		return nil
	end

	if data.words then
		local spell = Spells.getSpellByWords(data.words)

		if not spell then
			return nil
		end

		local spellRem, groupRem = getMultiActionCooldownRemaining(spell)
		local remaining = math.max(spellRem, groupRem)

		if remaining <= 0 then
			return nil
		end

		if spellRem < groupRem then
			local groupId = getActiveGroupCooldownId(spell)

			if not groupId then
				return nil
			end

			local totalDuration, remainingMs = AB.getGroupCooldownTiming(spell)

			return {
				useGroupCooldown = true,
				remaining = remaining,
				progressId = "progress" .. groupId,
				groupId = groupId,
				totalDuration = totalDuration,
				remainingMs = remainingMs
			}
		end

		local totalDuration, remainingMs = AB.getSpellCooldownTiming(spell.id)

		return {
			useGroupCooldown = false,
			remaining = remaining,
			progressId = "progress" .. spell.id,
			spellId = spell.id,
			totalDuration = totalDuration,
			remainingMs = remainingMs
		}
	elseif data.itemId and data.itemId > 0 then
		local runeSpell = AB.getRuneUsageSpell(data.itemId)

		if runeSpell then
			local spellRem, groupRem = getMultiActionCooldownRemaining(runeSpell)
			local remaining = math.max(spellRem, groupRem)

			if remaining <= 0 then
				return nil
			end

			if spellRem < groupRem then
				local groupId = getActiveGroupCooldownId(runeSpell)

				if not groupId then
					return nil
				end

				local totalDuration, remainingMs = AB.getGroupCooldownTiming(runeSpell)

				return {
					useGroupCooldown = true,
					remaining = remaining,
					progressId = "progress" .. groupId,
					groupId = groupId,
					totalDuration = totalDuration,
					remainingMs = remainingMs
				}
			end

			local totalDuration, remainingMs = AB.getSpellCooldownTiming(runeSpell.id)

			return {
				useGroupCooldown = false,
				remaining = remaining,
				progressId = "progress" .. runeSpell.id,
				spellId = runeSpell.id,
				totalDuration = totalDuration,
				remainingMs = remainingMs
			}
		end

		local remaining = readItemMultiUseCooldownRemaining()

		if remaining <= 0 then
			return nil
		end

		local totalDuration, remainingMs = AB.getItemMultiUseCooldownTiming()

		return {
			useGroupCooldown = true,
			remaining = remaining,
			progressId = "progress" .. MULTI_ITEM_CD_KEY,
			groupId = MULTI_ITEM_CD_KEY,
			totalDuration = totalDuration,
			remainingMs = remainingMs
		}
	end

	return nil
end

function AB.executeMultiActionSlot(slot, fromKeyboard)
	if not slot or slot:isDestroyed() or multiActionsEmpty(slot.multiActions) then
		return false
	end

	local activeIndex, action = resolveActiveSlot(slot.multiActions)

	if not action then
		return false
	end

	if not actionMatchesSlotDisplay(slot, action) or slot._activeMultiIndex ~= activeIndex then
		applyActionDataToSlot(slot, action)

		slot._activeMultiIndex = activeIndex
	end

	if executeActionSlot then
		executeActionSlot(slot, fromKeyboard)
	end

	scheduleEvent(function()
		if slot and not slot:isDestroyed() then
			AB.syncMultiActionSlot(slot)
		end
	end, 0)

	return true
end

function AB.initMultiActionStyles()
	g_ui.importStyle("/game_actionbar/multiaction")
end

function AB.initMultiActionSlot(slot)
	setMultiIconVisible(slot, false)
end

function AB.isEditingMultiActionSubSlot()
	return multiActionEditIndex ~= nil
end

function AB.clearMultiActionEditIndex()
	multiActionEditIndex = nil
end

function AB.commitMultiActionSubEntry(parentSlot, index, entry)
	if not parentSlot or not index then
		return
	end

	local multi = ensureSlotMultiActions(parentSlot)

	multi[index] = entry or {}

	setMultiIconVisible(parentSlot, true)
	registerMultiActionSlot(parentSlot)
	AB.syncMultiActionSlot(parentSlot)
	AB.saveActionBar()
end

function AB.updateMultiSlotState(slot, forceRotation)
	if not slot then
		return
	end

	if slot.multiActions == nil and not slot._multiPanelOpen then
		setMultiIconVisible(slot, false)

		slot._activeMultiIndex = nil

		return
	end

	setMultiIconVisible(slot, true)

	if multiActionsEmpty(slot.multiActions) then
		if clearSlotDisplayFields then
			clearSlotDisplayFields(slot)
		end

		if applyActionSlotFrame then
			applyActionSlotFrame(slot)
		end

		slot._activeMultiIndex = nil

		if clearSlotProgressWidgets then
			clearSlotProgressWidgets(slot)
		end

		return
	end

	registerMultiActionSlot(slot)

	local activeIndex, action = resolveActiveSlot(slot.multiActions)

	if not action then
		if clearSlotDisplayFields then
			clearSlotDisplayFields(slot)
		end

		if clearSlotProgressWidgets then
			clearSlotProgressWidgets(slot)
		end

		slot._activeMultiIndex = nil

		return
	end

	local previousIndex = slot._activeMultiIndex
	local alreadyShown = actionMatchesSlotDisplay(slot, action)

	if not alreadyShown or previousIndex ~= activeIndex then
		applyActionDataToSlot(slot, action)
		setMultiIconVisible(slot, true)
	elseif refreshMultiActionSlotCooldownDisplay then
		refreshMultiActionSlotCooldownDisplay(slot, true)
	end

	slot._activeMultiIndex = activeIndex
end

function AB.refreshAllMultiActionSlots()
	for _, slot in ipairs(cacheMultiActionSlots) do
		AB.syncMultiActionSlot(slot)
	end
end

function AB.onLocalPlayerManaChange(player, mana, maxMana, oldMana)
	if not player or player ~= g_game.getLocalPlayer() then
		return
	end

	oldMana = oldMana or mana

	if mana == oldMana then
		return
	end

	AB.refreshAllMultiActionSlots()
end

local function getBarIdFromSlot(slot)
	if slot._actionBarId then
		return slot._actionBarId
	end

	local barId = AB.getSlotBarId(slot:getId())

	return barId or BAR_BOTTOM_1
end

function AB.isBottomActionBar(barId)
	return barId and barId >= BAR_BOTTOM_1 and barId <= BAR_BOTTOM_3
end

function AB.getMultiActionLayout(barId)
	if AB.isBottomActionBar(barId) then
		return "slot-multi-action-bottom"
	end

	if barId and barId >= BAR_LEFT_1 and barId <= BAR_LEFT_3 then
		return "LeftMultiAction"
	end

	if barId and barId >= BAR_RIGHT_1 and barId <= BAR_RIGHT_3 then
		return "RightMultiAction"
	end

	return nil
end

function AB.getMultiActionPosition(slot)
	local barId = getBarIdFromSlot(slot)
	local pos = slot:getPosition()

	if barId >= BAR_BOTTOM_1 and barId <= BAR_BOTTOM_3 then
		return topoint(string.format("%s %s", slot:getX() - 28, slot:getY() - 116))
	end

	if barId >= BAR_LEFT_1 and barId <= BAR_LEFT_3 then
		return topoint(string.format("%s %s", slot:getX() + 34, slot:getY() - 28))
	end

	return topoint(string.format("%s %s", slot:getX() - 116, slot:getY() - 28))
end

local function configureMultiSubSlotCountDisplay(subSlot)
	if not subSlot or subSlot:isDestroyed() then
		return
	end

	local showCount = true

	if modules.client_options then
		showCount = modules.client_options.getOption("showHKObjectsBars") ~= false
	end

	subSlot._actionBarShowCount = showCount

	pcall(function()
		subSlot:setShowItemCount(false)
	end)
end

local function resetMultiSubSlotWidget(subSlot)
	if not subSlot then
		return
	end

	clearSlotDisplayFields(subSlot)
	subSlot:setTooltip("Action: None")

	if applyActionSlotFrame then
		applyActionSlotFrame(subSlot)
	end
end

local function paintMultiSubSlot(subSlot, data)
	resetMultiSubSlotWidget(subSlot)
	subSlot:setDraggable(true)

	if not data or table.empty(data) then
		return
	end

	if data.words then
		local spell = Spells.getSpellByWords(data.words)

		if spell then
			local spellName = spell.name or ""
			local profile = Spells.getSpellProfileByName(spellName) or "Default"
			local iconId = spell.clientId and tonumber(spell.clientId) or tonumber(Spells.getClientId(spellName))
			local icon = subSlot:getChildById("spellIcon")

			if icon and iconId then
				icon:setImageSource(Spells.getIconFileByProfile(profile))
				icon:setImageClip(Spells.getImageClip(iconId, profile))
				icon:show()
			end

			subSlot.words = data.words

			if data.parameter and data.parameter ~= "" then
				local lbl = subSlot:getChildById("spellParameter")

				if lbl then
					lbl:setVisible(true)

					local formatedParam = data.parameter:gsub("\"", "")

					lbl:setText(short_text("\"" .. formatedParam, 7))
				end
			end

			subSlot:setTooltip(spell.name or data.words)
		end

		subSlot.itemId = 469

		subSlot:setItemId(469)
	elseif data.text then
		subSlot.text = data.text

		subSlot:getChildById("text"):setText(data.text)

		subSlot.itemId = 469

		subSlot:setItemId(469)
		subSlot:setTooltip(data.text)
	elseif data.itemId and data.itemId > 0 then
		subSlot.itemId = data.itemId
		subSlot.subType = data.subType
		subSlot.useType = data.useType
		subSlot.getTier = data.getTier

		subSlot:setItemId(data.itemId)
		ItemsDatabase.setTier(subSlot, data.getTier or 0)
		configureMultiSubSlotCountDisplay(subSlot)

		local player = g_game.getLocalPlayer()

		if player then
			local count = player:getInventoryCount(data.itemId, multiActionEntryItemTier(data))
			local gray = subSlot:getChildById("gray")

			if gray then
				gray:setVisible(count == 0)
			end
		end

		if refreshActionSlotInventoryQuantity then
			refreshActionSlotInventoryQuantity(subSlot)
		end

		subSlot:setTooltip("Item " .. data.itemId)
	end

	if applyActionSlotFrame then
		applyActionSlotFrame(subSlot)
	end

	if refreshActionSlotVirtueBorder then
		refreshActionSlotVirtueBorder(subSlot)
	end
end

function AB.refreshMultiActionPanelVirtueBorders()
	if not multiPanel or multiPanel:isDestroyed() then
		return
	end

	for i = 1, 3 do
		local sub = multiPanel:recursiveGetChildById("actionButton" .. i)

		if sub and refreshActionSlotVirtueBorder then
			refreshActionSlotVirtueBorder(sub)
		end
	end
end

function AB.reapplyMultiSubSlotDisplayOpts()
	if not multiPanel or multiPanel:isDestroyed() then
		return
	end

	for i = 1, 3 do
		local sub = multiPanel:recursiveGetChildById("actionButton" .. i)

		if sub and not sub:isDestroyed() then
			configureMultiSubSlotCountDisplay(sub)

			if refreshActionSlotInventoryQuantity then
				refreshActionSlotInventoryQuantity(sub)
			end
		end
	end
end

function AB.refreshOpenMultiActionPanelInventory()
	if not multiPanel or multiPanel:isDestroyed() or not multiPanel.parentSlot then
		return
	end

	AB.refreshMultiActionPanel(multiPanel.parentSlot)
end

function AB.refreshMultiActionPanel(parentSlot)
	if not multiPanel or multiPanel.parentSlot ~= parentSlot then
		return
	end

	for i = 1, 3 do
		local sub = multiPanel:recursiveGetChildById("actionButton" .. i)

		if sub then
			local data = parentSlot.multiActions and parentSlot.multiActions[i] or nil

			paintMultiSubSlot(sub, data)
			refreshMultiSubSlotCooldownDisplay(sub, data, true)
		end
	end
end

function AB.refreshMultiActionPanelCooldowns(parentSlot, onlyIfMissing)
	if not multiPanel or multiPanel.parentSlot ~= parentSlot then
		return
	end

	for i = 1, 3 do
		local sub = multiPanel:recursiveGetChildById("actionButton" .. i)

		if sub then
			local data = parentSlot.multiActions and parentSlot.multiActions[i] or nil

			refreshMultiSubSlotCooldownDisplay(sub, data, onlyIfMissing)
		end
	end
end

local function openMultiSubSlotMenu(subSlot, parentSlot, index, mousePos)
	local menu = g_ui.createWidget("GamePopupMenu")

	menu:setGameMenu(true)

	local data = parentSlot.multiActions and parentSlot.multiActions[index] or nil
	local hasSpell = data and data.words
	local hasObject = data and data.itemId and data.itemId > 100
	local hasText = data and data.text and data.text ~= ""

	menu:addOption(hasSpell and tr("Edit Spell") or tr("Assign Spell"), function()
		multiActionEditIndex = index
		slotToEdit = parentSlot:getId()

		openSpellAssignWindow()
	end)
	menu:addOption(hasObject and tr("Edit Object") or tr("Assign Object"), function()
		multiActionEditIndex = index
		slotToEdit = parentSlot:getId()

		if hasObject then
			openObjectAssignWindow()

			local item = data.subType and Item.create(data.itemId, data.subType) or Item.create(data.itemId)

			populateObjectAssignWindowFromItem(item, data.useType, data.getTier, {
				smartMode = data.smartMode,
				smartBaseItemId = data.smartBaseItemId
			})
		else
			startChooseItem()
			openObjectAssignWindow()
		end
	end)
	menu:addOption(hasText and tr("Edit Text") or tr("Assign Text"), function()
		multiActionEditIndex = index
		slotToEdit = parentSlot:getId()

		openTextAssignWindow()
	end)

	if data and not table.empty(data) then
		menu:addSeparator()
		menu:addOption(tr("Clear Action"), function()
			parentSlot.multiActions[index] = {}

			if multiActionsEmpty(parentSlot.multiActions) then
				AB.clearSlotMultiActions(parentSlot)
			else
				AB.syncMultiActionSlot(parentSlot)
				AB.saveActionBar()
			end
		end)
	end

	menu:display(mousePos)
end

local function stopMultiPanelPositionTracking()
	if multiPanelPositionEvent then
		removeEvent(multiPanelPositionEvent)

		multiPanelPositionEvent = nil
	end
end

local function startMultiPanelPositionTracking(slot)
	stopMultiPanelPositionTracking()

	local function tick()
		multiPanelPositionEvent = nil

		if not multiPanel or multiPanel:isDestroyed() then
			return
		end

		if not slot or slot:isDestroyed() or not slot:isVisible() then
			AB.closeCurrentMultiActionPanel()

			return
		end

		multiPanel:setPosition(AB.getMultiActionPosition(slot))
		multiPanel:raise()

		multiPanelPositionEvent = scheduleEvent(tick, 50)
	end

	tick()
end

function AB.closeCurrentMultiActionPanel()
	stopMultiPanelPositionTracking()

	if multiPanel then
		local parentSlot = multiPanel.parentSlot

		if parentSlot and not parentSlot:isDestroyed() then
			parentSlot._multiPanelOpen = nil
			parentSlot.onVisibilityChange = nil

			setMultiIconVisible(parentSlot, true)
		end

		multiPanel:destroy()

		multiPanel = nil
	end
end

function AB.assignMultiAction(slotId, skipMigrate)
	local slot = AB.findSlotById(slotId)

	if not slot then
		return
	end

	local barId = getBarIdFromSlot(slot)

	slot._actionBarId = barId

	local layout = AB.getMultiActionLayout(barId)

	if not layout then
		return
	end

	if multiPanel and multiPanel.parentSlot ~= slot then
		AB.closeCurrentMultiActionPanel()
	end

	if not multiPanel then
		local root = modules.game_interface.getRootPanel()

		multiPanel = g_ui.createWidget(layout, root)

		if not multiPanel then
			return
		end

		multiPanel.parentSlot = slot

		function slot.onVisibilityChange()
			if not slot:isVisible() then
				AB.closeCurrentMultiActionPanel()
			end
		end

		startMultiPanelPositionTracking(slot)
	end

	slot._multiPanelOpen = true

	setMultiIconVisible(slot, true)

	local multi = ensureSlotMultiActions(slot)

	if not skipMigrate and multiActionsEmpty(multi) then
		if slot.words and slot.words ~= "" then
			multi[1] = {
				autoSend = true,
				words = slot.words,
				parameter = slot.parameter
			}
		elseif slot.text and slot.text ~= "" then
			multi[1] = {
				text = slot.text,
				autoSend = slot.autoSend ~= false
			}
		elseif slot.itemId and slot.itemId > 100 and not slot.passiveId then
			multi[1] = {
				itemId = slot.itemId,
				subType = slot.subType,
				useType = slot.useType,
				getTier = slot.getTier
			}
		end
	end

	registerMultiActionSlot(slot)
	AB.syncMultiActionSlot(slot)

	for i = 1, 3 do
		local sub = multiPanel:recursiveGetChildById("actionButton" .. i)

		if sub then
			sub.multiActionIndex = i
			sub.parentSlot = slot

			configureMultiSubSlotCountDisplay(sub)
			paintMultiSubSlot(sub, multi[i])
			g_mouse.bindPress(sub, function()
				return
			end, MouseLeftButton)
			g_mouse.bindPress(sub, function()
				openMultiSubSlotMenu(sub, slot, i, g_window.getMousePosition())
			end, MouseRightButton)
			g_mouse.bindOnDrop(sub, function()
				AB.handleDropOnMultiSubSlot(sub, slot, i)
			end)
		end
	end

	AB.refreshMultiActionPanel(slot)
	AB.saveActionBar()
end

function AB.clearSlotMultiActions(slot)
	if not slot then
		return
	end

	local closePanel = slot._multiPanelOpen or multiPanel and multiPanel.parentSlot == slot

	slot.multiActions = nil

	setMultiIconVisible(slot, false)
	unregisterMultiActionSlot(slot)

	slot._activeMultiIndex = nil

	if closePanel then
		AB.closeCurrentMultiActionPanel()
	end

	AB.saveActionBar()
end

function AB.detachMultiActionFromSlot(slot)
	if not slot then
		return
	end

	slot.multiActions = nil
	slot._activeMultiIndex = nil

	setMultiIconVisible(slot, false)
	unregisterMultiActionSlot(slot)
end

function AB.slotHasMultiActions(slot)
	return slot and slot.multiActions ~= nil
end

local function copyMultiActionEntry(data)
	if not data or table.empty(data) then
		return nil
	end

	local copy = {}

	for k, v in pairs(data) do
		local t = type(v)

		if t == "number" or t == "string" or t == "boolean" then
			copy[k] = v
		elseif t == "table" then
			-- block empty
		end
	end

	if table.empty(copy) then
		return nil
	end

	if copy.getTier ~= nil and type(copy.getTier) ~= "number" then
		copy.getTier = nil
	end

	return copy
end

function AB.serializeSlotMultiActions(slot)
	if not AB.slotHasMultiActions(slot) then
		return nil
	end

	local out = {}
	local any = false

	for i = 1, 3 do
		local entry = slot.multiActions and copyMultiActionEntry(slot.multiActions[i]) or nil

		if entry then
			out[tostring(i)] = entry
			any = true
		end
	end

	if not any then
		return {
			__multiActionSlot = true
		}
	end

	return out
end

local function normalizeSavedMultiActions(saved)
	if type(saved) ~= "table" then
		return nil
	end

	if saved.__multiActionSlot then
		return {
			{},
			{},
			{}
		}
	end

	local normalized = {
		{},
		{},
		{}
	}
	local any = false

	for i = 1, 3 do
		local raw = saved[i] or saved[tostring(i)]
		local entry = copyMultiActionEntry(raw)

		if entry then
			normalized[i] = entry
			any = true
		end
	end

	return any and normalized or nil
end

function AB.loadSlotMultiActions(slot, saved)
	if not saved or table.empty(saved) then
		AB.initMultiActionSlot(slot)

		return
	end

	local normalized = normalizeSavedMultiActions(saved)

	if not normalized then
		AB.initMultiActionSlot(slot)

		return
	end

	slot.multiActions = normalized

	if not multiActionsEmpty(slot.multiActions) then
		setMultiIconVisible(slot, true)
		registerMultiActionSlot(slot)
		AB.syncMultiActionSlot(slot)
	else
		setMultiIconVisible(slot, true)
	end
end

function AB.onMultiActionSpellCooldown(iconSpellId, delay)
	local triggerSpell = Spells.getSpellByIcon(iconSpellId)

	if not triggerSpell then
		return
	end

	spellCooldownCache[triggerSpell.id] = {
		exhaustion = delay,
		startTime = g_clock.millis()
	}
end

function AB.onMultiActionSpellGroupCooldown(groupId, delay)
	spellGroupCooldownCache[groupId] = {
		exhaustion = delay,
		startTime = g_clock.millis()
	}
end

function AB.onMultiActionItemMultiUseCooldown(duration)
	if not duration or duration <= 0 then
		itemMultiUseCooldownCache = nil
	else
		itemMultiUseCooldownCache = {
			exhaustion = duration,
			startTime = g_clock.millis()
		}
	end
end

function AB.buildMultiActionEntryFromSlot(slot)
	if not slot or slot:isDestroyed() then
		return nil
	end

	if slot.passiveId then
		return nil
	end

	if slot.equipments then
		return nil
	end

	if slot.words and slot.words ~= "" then
		return {
			words = slot.words,
			parameter = slot.parameter,
			autoSend = slot.autoSend ~= false
		}
	end

	if slot.text and slot.text ~= "" then
		return {
			text = slot.text,
			autoSend = slot.autoSend ~= false
		}
	end

	if slot.itemId and slot.itemId > 0 and slot.itemId ~= 469 then
		return {
			itemId = slot.itemId,
			subType = slot.subType,
			useType = slot.useType,
			getTier = slot.getTier
		}
	end

	return nil
end

function AB.applyMultiActionEntryToRegularSlot(slot, entry)
	if not slot or slot:isDestroyed() then
		return false
	end

	if clearSlotActionContent then
		clearSlotActionContent(slot)
	end

	if not entry or table.empty(entry) then
		if applyActionSlotFrame then
			applyActionSlotFrame(slot)
		end

		return true
	end

	if entry.words then
		slot.words = entry.words
		slot.parameter = entry.parameter
		slot.autoSend = entry.autoSend ~= false

		if loadSpell then
			loadSpell(slot)
		end
	elseif entry.text then
		slot.text = entry.text
		slot.autoSend = entry.autoSend ~= false

		if loadText then
			loadText(slot)
		end
	elseif entry.itemId and entry.itemId > 0 then
		slot.itemId = entry.itemId
		slot.subType = entry.subType
		slot.useType = entry.useType
		slot.getTier = entry.getTier

		if loadObject then
			loadObject(slot)
		end
	end

	if applyActionSlotFrame then
		applyActionSlotFrame(slot)
	end

	return true
end

local function resolveExternalDraggedItem(pressed)
	if not pressed or pressed:isDestroyed() then
		return nil
	end

	if pressed:isVirtual() then
		return nil
	end

	local thing = pressed.currentDragThing

	if not thing or thing == pressed then
		return nil
	end

	if type(thing.isItem) ~= "function" or not thing:isItem() then
		return nil
	end

	return thing
end

function AB.handleDropOnMultiSubSlot(targetSubSlot, targetParentSlot, targetIndex)
	if not targetSubSlot or targetSubSlot:isDestroyed() then
		return
	end

	if not targetParentSlot or targetParentSlot:isDestroyed() then
		return
	end

	if isActionBarLocked and isActionBarLocked(targetParentSlot._actionBarId) then
		return
	end

	if not targetIndex then
		return
	end

	local pressed = g_ui.getPressedWidget()

	if not pressed or pressed == targetSubSlot then
		return
	end

	if pressed.multiActionIndex and pressed.parentSlot then
		local fromParent = pressed.parentSlot
		local fromIndex = pressed.multiActionIndex

		if not fromParent or fromParent:isDestroyed() or not fromIndex then
			return
		end

		if fromParent == targetParentSlot and fromIndex == targetIndex then
			return
		end

		ensureSlotMultiActions(fromParent)
		ensureSlotMultiActions(targetParentSlot)

		local fromEntry = copyMultiActionEntry(fromParent.multiActions[fromIndex])
		local toEntry = copyMultiActionEntry(targetParentSlot.multiActions[targetIndex])

		fromParent.multiActions[fromIndex] = toEntry or {}
		targetParentSlot.multiActions[targetIndex] = fromEntry or {}

		if fromParent ~= targetParentSlot then
			if multiActionsEmpty(fromParent.multiActions) then
				AB.updateMultiSlotState(fromParent, true)
			else
				registerMultiActionSlot(fromParent)
				AB.syncMultiActionSlot(fromParent)
			end
		end

		if multiActionsEmpty(targetParentSlot.multiActions) then
			AB.updateMultiSlotState(targetParentSlot, true)
		else
			registerMultiActionSlot(targetParentSlot)
			AB.syncMultiActionSlot(targetParentSlot)
		end

		AB.refreshMultiActionPanel(targetParentSlot)

		if saveActionBar then
			saveActionBar()
		end

		return
	end

	if pressed:getClassName() == "UIActionSlot" then
		if pressed.multiActions ~= nil then
			return
		end

		if pressed == targetParentSlot then
			return
		end

		local sourceEntry = AB.buildMultiActionEntryFromSlot(pressed)

		if not sourceEntry then
			return
		end

		ensureSlotMultiActions(targetParentSlot)

		local existingEntry = copyMultiActionEntry(targetParentSlot.multiActions[targetIndex])

		targetParentSlot.multiActions[targetIndex] = sourceEntry

		AB.applyMultiActionEntryToRegularSlot(pressed, existingEntry)
		registerMultiActionSlot(targetParentSlot)
		AB.syncMultiActionSlot(targetParentSlot)
		AB.refreshMultiActionPanel(targetParentSlot)

		if saveActionBar then
			saveActionBar()
		end

		return
	end

	local pressedClass = pressed:getClassName()

	if pressedClass == "UIItem" or pressedClass == "UIGameMap" then
		local item = resolveExternalDraggedItem(pressed)

		if not item then
			return
		end

		multiActionEditIndex = targetIndex
		slotToEdit = targetParentSlot:getId()

		if openObjectAssignWindow then
			openObjectAssignWindow()
		end

		if populateObjectAssignWindowFromItem then
			populateObjectAssignWindowFromItem(item)
		end

		return
	end
end

function AB.handleDropFromMultiSubSlotOntoSlot(sourceSubSlot, targetSlotId)
	if not sourceSubSlot or sourceSubSlot:isDestroyed() then
		return
	end

	local fromParent = sourceSubSlot.parentSlot
	local fromIndex = sourceSubSlot.multiActionIndex

	if not fromParent or fromParent:isDestroyed() or not fromIndex then
		return
	end

	if isActionBarLocked and isActionBarLocked(fromParent._actionBarId) then
		return
	end

	local targetSlot = findSlotById and findSlotById(targetSlotId) or nil

	if not targetSlot or targetSlot:isDestroyed() then
		return
	end

	if isActionBarLocked and isActionBarLocked(targetSlot._actionBarId) then
		return
	end

	if targetSlot == fromParent then
		return
	end

	local sourceEntry = copyMultiActionEntry(fromParent.multiActions and fromParent.multiActions[fromIndex])

	if not sourceEntry then
		return
	end

	local targetReplacement = AB.buildMultiActionEntryFromSlot(targetSlot)

	AB.applyMultiActionEntryToRegularSlot(targetSlot, sourceEntry)
	ensureSlotMultiActions(fromParent)

	fromParent.multiActions[fromIndex] = targetReplacement or {}

	if multiActionsEmpty(fromParent.multiActions) then
		AB.updateMultiSlotState(fromParent, true)
		AB.refreshMultiActionPanel(fromParent)
	else
		registerMultiActionSlot(fromParent)
		AB.syncMultiActionSlot(fromParent)
		AB.refreshMultiActionPanel(fromParent)
	end

	if saveActionBar then
		saveActionBar()
	end
end

function AB.terminateMultiAction()
	stopMultiPanelPositionTracking()
	stopMultiActionSyncTick()
	AB.closeCurrentMultiActionPanel()

	cacheMultiActionSlots = {}
	spellCooldownCache = {}
	spellGroupCooldownCache = {}
	itemMultiUseCooldownCache = nil
end

initMultiActionStyles = AB.initMultiActionStyles
initMultiActionSlot = AB.initMultiActionSlot
assignMultiAction = AB.assignMultiAction
isBottomActionBar = AB.isBottomActionBar
closeCurrentMultiActionPanel = AB.closeCurrentMultiActionPanel
updateMultiSlotState = AB.updateMultiSlotState
refreshAllMultiActionSlots = AB.refreshAllMultiActionSlots
getRuneUsageSpell = AB.getRuneUsageSpell
onLocalPlayerManaChangeMultiAction = AB.onLocalPlayerManaChange
shouldPaintItemMultiCdOnMainSlot = AB.shouldPaintItemMultiCdOnMainSlot
refreshMultiActionPanel = AB.refreshMultiActionPanel
refreshMultiActionPanelCooldowns = AB.refreshMultiActionPanelCooldowns
reapplyMultiSubSlotDisplayOpts = AB.reapplyMultiSubSlotDisplayOpts
refreshOpenMultiActionPanelInventory = AB.refreshOpenMultiActionPanelInventory
clearSlotMultiActions = AB.clearSlotMultiActions
detachMultiActionFromSlot = AB.detachMultiActionFromSlot
slotHasMultiActions = AB.slotHasMultiActions
serializeSlotMultiActions = AB.serializeSlotMultiActions
loadSlotMultiActions = AB.loadSlotMultiActions
onMultiActionSpellCooldown = AB.onMultiActionSpellCooldown
onMultiActionSpellGroupCooldown = AB.onMultiActionSpellGroupCooldown
onMultiActionItemMultiUseCooldown = AB.onMultiActionItemMultiUseCooldown
getMultiActionCooldownRemaining = AB.getMultiActionCooldownRemaining
getMultiActionSpellCooldownTiming = AB.getSpellCooldownTiming
getMultiActionGroupCooldownTiming = AB.getGroupCooldownTiming
getMultiActionItemCooldownTiming = AB.getItemMultiUseCooldownTiming
getItemMultiUseCooldownRemaining = AB.getItemMultiUseCooldownRemaining
clearItemMultiUseCooldownCache = AB.clearItemMultiUseCooldownCache
getMultiActionActiveGroupId = AB.getMultiActionActiveGroupId
syncMultiActionSlot = AB.syncMultiActionSlot
executeMultiActionSlot = AB.executeMultiActionSlot
terminateMultiAction = AB.terminateMultiAction
commitMultiActionSubEntry = AB.commitMultiActionSubEntry
refreshMultiActionPanelVirtueBorders = AB.refreshMultiActionPanelVirtueBorders
buildMultiActionEntryFromSlot = AB.buildMultiActionEntryFromSlot
applyMultiActionEntryToRegularSlot = AB.applyMultiActionEntryToRegularSlot
handleDropOnMultiSubSlot = AB.handleDropOnMultiSubSlot
handleDropFromMultiSubSlotOntoSlot = AB.handleDropFromMultiSubSlotOntoSlot
