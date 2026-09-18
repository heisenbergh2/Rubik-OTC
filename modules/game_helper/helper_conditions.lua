-- chunkname: @/game_helper/helper_conditions.lua

HelperConditions = HelperConditions or {}

local ctx
local conditionsUiLanguage = "en"
local hasteSlot, manaTrainingSlot
local lastHasteCastMs = 0
local lastManaTrainingCastMs = 0
local conditionsTickEvent
local helperCooldowns = {
	spells = {},
	groups = {}
}
local cdConnected = false
local cachedHasteSpell, cachedHasteWords, cachedManaTrainingSpell, cachedManaTrainingWords, cachedMainCheck
local CONDITIONS_UI_TEXT = {
	en = {
		clearAction = "Clear Action",
		typeToSearch = "Type to search",
		assignSpell = "Assign Spell",
		haste = "Haste",
		editSpell = "Edit Spell"
	},
	pt = {
		clearAction = "Limpar Acao",
		typeToSearch = "Digite para pesquisar",
		assignSpell = "Selecionar Magia",
		haste = "Acelerar",
		editSpell = "Editar Magia"
	}
}

local function conditionsText(key)
	local texts = CONDITIONS_UI_TEXT[conditionsUiLanguage] or CONDITIONS_UI_TEXT.en

	return texts[key] or CONDITIONS_UI_TEXT.en[key] or key
end

local function invalidateHasteSpellCache()
	cachedHasteSpell = nil
	cachedHasteWords = nil
end

local function invalidateManaTrainingSpellCache()
	cachedManaTrainingSpell = nil
	cachedManaTrainingWords = nil
end

local function refreshWidgetCache()
	if not ctx then
		return
	end

	cachedMainCheck = ctx.getWidget("checkbox")
end

local function clearWidgetCache()
	cachedMainCheck = nil
end

local function getCachedSpell(words, cachedWords, cachedSpell)
	words = words:gsub("^%s+", ""):gsub("%s+$", "")

	if words == "" then
		return nil, cachedWords, cachedSpell
	end

	if cachedWords == words then
		if cachedSpell == false then
			return nil, cachedWords, cachedSpell
		end

		return cachedSpell, cachedWords, cachedSpell
	end

	cachedWords = words

	local spell = Spells.getSpellByWords and Spells.getSpellByWords(words) or nil

	cachedSpell = spell or false

	return spell, cachedWords, cachedSpell
end

local function getCachedHasteSpell(words)
	local spell

	spell, cachedHasteWords, cachedHasteSpell = getCachedSpell(words, cachedHasteWords, cachedHasteSpell)

	return spell
end

local function getCachedManaTrainingSpell(words)
	local spell

	spell, cachedManaTrainingWords, cachedManaTrainingSpell = getCachedSpell(words, cachedManaTrainingWords, cachedManaTrainingSpell)

	return spell
end

local ACTION_SLOT_SPELL_ITEM_ID = 469
local HASTE_SPELL_WORDS = {
	["utani gran hur"] = true,
	["utani hur"] = true,
	["utamo tempo san"] = true,
	["utani tempo hur"] = true
}

local function actionbar()
	return modules.game_actionbar
end

local function centerHasteSpellIcon()
	for _, slot in ipairs({
		hasteSlot,
		manaTrainingSlot
	}) do
		if slot then
			local spellIcon = slot:getChildById("spellIcon")

			if spellIcon then
				spellIcon:setMarginLeft(0)
				spellIcon:setMarginTop(0)
			end
		end
	end
end

local function centerSlotSpellIcon(slot)
	if not slot then
		return
	end

	local spellIcon = slot:getChildById("spellIcon")

	if spellIcon then
		spellIcon:setMarginLeft(0)
		spellIcon:setMarginTop(0)
	end
end

local function prepareHelperActionSlot(slot)
	if not slot then
		return
	end

	if slot.text and type(slot.text) ~= "string" then
		slot.text = nil
	end
end

local SLOT_IMG_EMPTY = "/images/game/actionbar/slot-actionbar-empty"
local SLOT_CLIP_EMPTY = "0 0 34 34"

local function applyEmptyHelperSlotFrame(slot)
	if not slot or slot:isDestroyed() then
		return
	end

	slot:setImageSource(SLOT_IMG_EMPTY)
	slot:setImageSize(tosize("34 34"))
	slot:setImageClip(SLOT_CLIP_EMPTY)

	slot._actionBarFilledFrame = false
end

local function refreshSlotVisual(slot)
	local ab = actionbar()

	if not slot or not ab then
		return
	end

	prepareHelperActionSlot(slot)

	if ab.applyActionSlotFrame then
		ab.applyActionSlotFrame(slot)
	end

	local hasSpell = slot.words and slot.words ~= ""
	local hasItem = slot.itemId and slot.itemId > 0

	if hasSpell or hasItem then
		if ab.updateSlotGray then
			ab.updateSlotGray(slot)
		end

		if ab.refreshActionSlotInventoryQuantity then
			ab.refreshActionSlotInventoryQuantity(slot)
		end

		if ab.refreshActionSlotTooltip then
			ab.refreshActionSlotTooltip(slot)
		end
	end

	if slot == hasteSlot or slot == manaTrainingSlot then
		centerSlotSpellIcon(slot)
	end
end

local function capitalizeWords(text)
	if not text or text == "" then
		return ""
	end

	return (text:gsub("(%a)([%w_']*)", function(a, rest)
		return a:upper() .. rest:lower()
	end))
end

local function getHasteSpellDisplayName(words)
	words = words and words:gsub("^%s+", ""):gsub("%s+$", "") or ""

	if words == "" then
		return nil
	end

	return capitalizeWords(words)
end

local function refreshHasteLabel()
	if not ctx then
		return
	end

	local label = ctx.getWidget("toolsAutoHasteLabel")

	if not label then
		return
	end

	local words = hasteSlot and hasteSlot.words or nil

	if not words or words == "" then
		label:setText(conditionsText("haste"))

		return
	end

	local spellName = getHasteSpellDisplayName(words)

	label:setText(spellName or conditionsText("haste"))
end

function HelperConditions.refreshLanguage(language)
	conditionsUiLanguage = language == "pt" and "pt" or "en"

	refreshHasteLabel()
end

local function clearSlotData(slot)
	local ab = actionbar()

	if ab and ab.clearSlotActionContent then
		ab.clearSlotActionContent(slot)

		if slot == hasteSlot or slot == manaTrainingSlot then
			applyEmptyHelperSlotFrame(slot)
			centerSlotSpellIcon(slot)

			if slot == hasteSlot then
				invalidateHasteSpellCache()
			else
				invalidateManaTrainingSpellCache()
			end
		end

		refreshHasteLabel()

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
	slot.words = nil
	slot.text = nil
	slot.subType = nil
	slot.useType = nil
	slot.parameter = nil

	if slot == hasteSlot or slot == manaTrainingSlot then
		applyEmptyHelperSlotFrame(slot)
		centerSlotSpellIcon(slot)

		if slot == hasteSlot then
			invalidateHasteSpellCache()
		else
			invalidateManaTrainingSpellCache()
		end
	else
		refreshSlotVisual(slot)
	end

	refreshHasteLabel()
end

local function restoreSlotData(slot, data)
	if not slot or not data then
		return
	end

	clearSlotData(slot)

	slot.words = data.words
	slot.itemId = data.itemId
	slot.subType = data.subType
	slot.useType = data.useType
	slot.parameter = data.parameter

	local ab = actionbar()

	if data.words and data.words ~= "" then
		if slot.setItemId then
			slot:setItemId(ACTION_SLOT_SPELL_ITEM_ID)
		end

		if ab and ab.loadSpell then
			ab.loadSpell(slot)
			centerSlotSpellIcon(slot)
		else
			refreshSlotVisual(slot)
		end
	elseif data.itemId and data.itemId > 0 then
		if slot.setItemId then
			slot:setItemId(data.itemId)
		end

		if ab and ab.loadObject then
			ab.loadObject(slot)
		else
			refreshSlotVisual(slot)
		end
	end

	refreshHasteLabel()
end

local function isHelperHasteSpell(_, spellData)
	if not spellData then
		return false
	end

	local words = (spellData.words or ""):lower()

	if not HASTE_SPELL_WORDS[words] then
		return false
	end

	local voc = ctx.getPlayerVoc()

	return table.contains(spellData.vocations, voc)
end

local function isHelperManaTrainingSpell(_, spellData)
	if not spellData then
		return false
	end

	if spellData.special then
		return false
	end

	local words = (spellData.words or ""):lower()

	if HASTE_SPELL_WORDS[words] then
		return false
	end

	if words:find("res", 1, true) or words:find("exiva", 1, true) or words:find("tempo", 1, true) or words:find("vita", 1, true) then
		return false
	end

	local groups = spellData.group or {}

	if groups[1] or groups[2] then
		return false
	end

	local voc = ctx.getPlayerVoc()

	return table.contains(spellData.vocations, voc)
end

local function openHelperSpellAssign(slot, filterFn)
	local ab = actionbar()

	if not ab or not ab.openHelperSpellAssignWindow then
		return
	end

	local slotId = slot:getId()

	if not slotId or slotId == "" then
		return
	end

	ab.openHelperSpellAssignWindow(slot, slotId, filterFn, function()
		refreshSlotVisual(slot)
		centerSlotSpellIcon(slot)
		refreshHasteLabel()

		if slot == hasteSlot then
			invalidateHasteSpellCache()
		elseif slot == manaTrainingSlot then
			invalidateManaTrainingSpellCache()
		end

		ctx.saveConfig()
	end)

	local window = ab.spellAssignWindow

	if window and not window:isDestroyed() then
		if ctx.applyWidgetLanguage then
			ctx.applyWidgetLanguage(window)
		end

		window:setText(conditionsText(slot.words and slot.words ~= "" and "editSpell" or "assignSpell"))

		local filterEdit = window:recursiveGetChildById("filterTextEdit")

		if filterEdit and filterEdit.setPlaceholder then
			filterEdit:setPlaceholder(conditionsText("typeToSearch"))
		end
	end
end

local function openHasteSlotContextMenu(slot)
	local menu = g_ui.createWidget("GamePopupMenu")

	menu:setWidth(220)
	menu:addOption(conditionsText("assignSpell"), function()
		openHelperSpellAssign(slot, isHelperHasteSpell)
	end)
	menu:addSeparator()
	menu:addOption(conditionsText("clearAction"), function()
		clearSlotData(slot)
		ctx.saveConfig()
	end)
	menu:display()
end

local function openManaTrainingSlotContextMenu(slot)
	local menu = g_ui.createWidget("GamePopupMenu")

	menu:setWidth(220)
	menu:addOption(conditionsText("assignSpell"), function()
		openHelperSpellAssign(slot, isHelperManaTrainingSpell)
	end)
	menu:addSeparator()
	menu:addOption(conditionsText("clearAction"), function()
		clearSlotData(slot)
		ctx.saveConfig()
	end)
	menu:display()
end

local function refreshActionSlotFrame(slot)
	if not slot or slot:isDestroyed() then
		return
	end

	local hasSpell = slot.words and slot.words ~= ""
	local hasItem = slot.itemId and slot.itemId > 0

	if hasSpell or hasItem then
		refreshSlotVisual(slot)
	else
		prepareHelperActionSlot(slot)
		applyEmptyHelperSlotFrame(slot)
		centerSlotSpellIcon(slot)
	end
end

local function refreshHasteSlotFrame()
	refreshActionSlotFrame(hasteSlot)
end

local function refreshManaTrainingSlotFrame()
	refreshActionSlotFrame(manaTrainingSlot)
end

local function bindHasteSlot()
	if not ctx then
		return
	end

	local slot = ctx.getWidget("toolsAutoHasteSlot")

	if not slot then
		return
	end

	hasteSlot = slot

	slot:setVisible(true)
	prepareHelperActionSlot(slot)
	refreshHasteSlotFrame()
	refreshHasteLabel()

	function slot:onMouseRelease(mousePos, button)
		if button == MouseRightButton then
			openHasteSlotContextMenu(self)

			return true
		end

		if button == MouseLeftButton then
			openHelperSpellAssign(self, isHelperHasteSpell)

			return true
		end
	end
end

local function bindManaTrainingSlot()
	if not ctx then
		return
	end

	local slot = ctx.getWidget("toolsManaTrainingSlot")

	if not slot then
		return
	end

	manaTrainingSlot = slot

	slot:setVisible(true)
	prepareHelperActionSlot(slot)
	refreshManaTrainingSlotFrame()

	function slot:onMouseRelease(mousePos, button)
		if button == MouseRightButton then
			openManaTrainingSlotContextMenu(self)

			return true
		end

		if button == MouseLeftButton then
			openHelperSpellAssign(self, isHelperManaTrainingSpell)

			return true
		end
	end
end

local function getHasteWords()
	if not hasteSlot then
		bindHasteSlot()
	end

	if not hasteSlot or not hasteSlot.words or hasteSlot.words == "" then
		return nil
	end

	return hasteSlot.words
end

local function getManaTrainingWords()
	if not manaTrainingSlot then
		bindManaTrainingSlot()
	end

	if not manaTrainingSlot or not manaTrainingSlot.words or manaTrainingSlot.words == "" then
		return nil
	end

	return manaTrainingSlot.words
end

local function getManaTrainingThreshold()
	local combo = ctx and ctx.getWidget("toolsManaTrainingManaCombo") or nil

	if not combo or not combo.getCurrentOption then
		return 50
	end

	local current = combo:getCurrentOption()

	if type(current) == "table" then
		current = current.text or current.value or current.data
	end

	if type(current) == "string" then
		current = current:gsub("%%", "")
	end

	local value = tonumber(current) or 50

	if value < 0 then
		return 0
	end

	if value > 100 then
		return 100
	end

	return value
end

local function onSpellCD(id, delay)
	helperCooldowns.spells[Spells.resolveSpellId(id)] = g_clock.millis() + delay
end

local function onSpellGroupCD(id, delay)
	helperCooldowns.groups[id] = g_clock.millis() + delay
end

local function isHasteEnabled()
	if not cachedMainCheck or cachedMainCheck:isDestroyed() then
		refreshWidgetCache()
	end

	if not cachedMainCheck or not cachedMainCheck:isChecked() then
		return false
	end

	local hasteCheck = ctx and ctx.getWidget("toolsAutoHasteCheckBox") or nil

	return hasteCheck and hasteCheck:isChecked() or false
end

local function isManaTrainingEnabled()
	if not cachedMainCheck or cachedMainCheck:isDestroyed() then
		refreshWidgetCache()
	end

	if not cachedMainCheck or not cachedMainCheck:isChecked() then
		return false
	end

	local manaTrainingCheck = ctx and ctx.getWidget("toolsManaTrainingCheckBox") or nil

	return manaTrainingCheck and manaTrainingCheck:isChecked() or false
end

local function runAutoHaste()
	if not isHasteEnabled() then
		return
	end

	local words = getHasteWords()

	if not words then
		return
	end

	local lp = g_game.getLocalPlayer()

	if not lp then
		return
	end

	local pzCastCheck = ctx and ctx.getWidget("toolsAutoHastePzCastCheckBox") or nil
	local allowPzCast = pzCastCheck and pzCastCheck:isChecked() or false

	if not allowPzCast and lp.isInProtectionZone and lp:isInProtectionZone() then
		return
	end

	local spell = getCachedHasteSpell(words)

	if not spell then
		return
	end

	local now = g_clock.millis()

	if now < (helperCooldowns.spells[spell.id] or 0) then
		return
	end

	if spell.group then
		for groupId in pairs(spell.group) do
			if now < (helperCooldowns.groups[groupId] or 0) then
				return
			end
		end
	end

	local duration = tonumber(spell.duration) or 30000

	if now < lastHasteCastMs + math.max(duration - 500, 1000) then
		return
	end

	g_game.talk(spell.words, true)

	lastHasteCastMs = now
end

local function runManaTraining()
	if not isManaTrainingEnabled() then
		return
	end

	local words = getManaTrainingWords()

	if not words then
		return
	end

	local lp = g_game.getLocalPlayer()

	if not lp then
		return
	end

	local spell = getCachedManaTrainingSpell(words)

	if not spell then
		return
	end

	local maxMana = lp:getMaxMana()

	if not maxMana or maxMana <= 0 then
		return
	end

	local manaPercent = lp:getMana() / maxMana * 100

	if manaPercent <= getManaTrainingThreshold() then
		return
	end

	local now = g_clock.millis()

	if now < (helperCooldowns.spells[spell.id] or 0) then
		return
	end

	if spell.group then
		for groupId in pairs(spell.group) do
			if now < (helperCooldowns.groups[groupId] or 0) then
				return
			end
		end
	end

	local duration = tonumber(spell.exhaustion) or 1000

	if now < lastManaTrainingCastMs + math.max(duration, 1000) then
		return
	end

	g_game.talk(spell.words, true)

	lastManaTrainingCastMs = now
end

function HelperConditions.init(pctx)
	ctx = pctx

	HelperConditions.refreshLanguage(ctx and ctx.getLanguage and ctx.getLanguage() or "en")
	refreshWidgetCache()
	bindHasteSlot()
	bindManaTrainingSlot()

	if not cdConnected then
		connect(g_game, {
			onSpellCooldown = onSpellCD,
			onSpellGroupCooldown = onSpellGroupCD
		})

		cdConnected = true
	end

	if not conditionsTickEvent then
		conditionsTickEvent = cycleEvent(function()
			if not g_game.isOnline() then
				return
			end

			if not cachedMainCheck or cachedMainCheck:isDestroyed() then
				refreshWidgetCache()
			end

			local ok, err = pcall(function()
				runAutoHaste()
				runManaTraining()
			end)

			if not ok and g_logger then
				g_logger.error("[helper_conditions] " .. tostring(err))
			end
		end, 500)
	end
end

function HelperConditions.onShow()
	refreshWidgetCache()
	bindHasteSlot()
	bindManaTrainingSlot()
end

function HelperConditions.onHide()
	clearWidgetCache()
end

function HelperConditions.terminate()
	if conditionsTickEvent then
		removeEvent(conditionsTickEvent)

		conditionsTickEvent = nil
	end

	if cdConnected then
		disconnect(g_game, {
			onSpellCooldown = onSpellCD,
			onSpellGroupCooldown = onSpellGroupCD
		})

		cdConnected = false
	end

	clearWidgetCache()
	invalidateHasteSpellCache()
	invalidateManaTrainingSpellCache()

	conditionsUiLanguage = "en"
end

function HelperConditions.onEnableConditionsChange(_, _)
	if ctx and ctx.saveConfig then
		ctx.saveConfig()
	end
end

function HelperConditions.collectConfig(config)
	config.tools = config.tools or {}

	local hasteCheck = ctx.getWidget("toolsAutoHasteCheckBox")
	local pzCastCheck = ctx.getWidget("toolsAutoHastePzCastCheckBox")
	local manaTrainingCheck = ctx.getWidget("toolsManaTrainingCheckBox")

	if not hasteSlot then
		bindHasteSlot()
	end

	if not manaTrainingSlot then
		bindManaTrainingSlot()
	end

	config.tools.autoHaste = hasteCheck and hasteCheck:isChecked() or false
	config.tools.autoHastePzCast = pzCastCheck and pzCastCheck:isChecked() or false
	config.tools.autoManaTraining = manaTrainingCheck and manaTrainingCheck:isChecked() or false
	config.tools.autoManaTrainingMana = getManaTrainingThreshold()

	if hasteSlot then
		config.tools.autoHasteSlot = {
			words = hasteSlot.words,
			itemId = hasteSlot.itemId,
			subType = hasteSlot.subType,
			useType = hasteSlot.useType,
			parameter = hasteSlot.parameter
		}
	end

	if manaTrainingSlot then
		config.tools.autoManaTrainingSlot = {
			words = manaTrainingSlot.words,
			itemId = manaTrainingSlot.itemId,
			subType = manaTrainingSlot.subType,
			useType = manaTrainingSlot.useType,
			parameter = manaTrainingSlot.parameter
		}
	end
end

function HelperConditions.loadFromConfig(config)
	local data = config.tools or {}
	local legacy = config.conditions or {}
	local hasteCheck = ctx.getWidget("toolsAutoHasteCheckBox")
	local pzCastCheck = ctx.getWidget("toolsAutoHastePzCastCheckBox")
	local manaTrainingCheck = ctx.getWidget("toolsManaTrainingCheckBox")
	local manaTrainingCombo = ctx.getWidget("toolsManaTrainingManaCombo")

	bindHasteSlot()
	bindManaTrainingSlot()

	if hasteCheck then
		local autoHaste = data.autoHaste

		if autoHaste == nil then
			autoHaste = legacy.autoHaste == true
		end

		hasteCheck:setChecked(autoHaste == true)
	end

	if pzCastCheck then
		local pzCast = data.autoHastePzCast

		if pzCast == nil then
			pzCast = legacy.autoHastePzCast == true
		end

		pzCastCheck:setChecked(pzCast == true)
	end

	if manaTrainingCheck then
		manaTrainingCheck:setChecked(data.autoManaTraining == true)
	end

	if manaTrainingCombo and manaTrainingCombo.setCurrentOption then
		manaTrainingCombo:setCurrentOption(tostring(tonumber(data.autoManaTrainingMana) or 50) .. "%")
	end

	if hasteSlot then
		local slotData = data.autoHasteSlot or legacy.autoHasteSlot

		if slotData then
			restoreSlotData(hasteSlot, slotData)
		elseif legacy.autoHasteSpell and legacy.autoHasteSpell ~= "" then
			restoreSlotData(hasteSlot, {
				words = legacy.autoHasteSpell
			})
		end
	end

	if manaTrainingSlot then
		local slotData = data.autoManaTrainingSlot

		if slotData then
			restoreSlotData(manaTrainingSlot, slotData)
		end
	end
end
