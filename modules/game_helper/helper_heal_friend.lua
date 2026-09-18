-- chunkname: @/game_helper/helper_heal_friend.lua

HelperHealFriend = HelperHealFriend or {}

local ctx
local HEAL_FRIEND_PANEL_BY_VOC = {
	[2] = {
		true,
		true,
		false
	},
	[6] = {
		true,
		true,
		false
	},
	[9] = {
		false,
		false,
		true
	},
	[10] = {
		false,
		false,
		true
	}
}
local SPELLS_BY_PANEL = {
	{
		words = "exura sio",
		id = 84,
		label = "Exura Sio"
	},
	{
		words = "exura gran sio",
		id = 242,
		label = "Exura Gran Sio"
	},
	{
		words = "exura tio sio",
		id = 297,
		label = "Exura Tio Sio"
	}
}
local CLASS_KEYS = {
	"Knight",
	"Paladin",
	"Sorcerer",
	"Druid",
	"Monk"
}
local DEFAULT_PRIORITY_BY_CLASS = {
	Monk = 1,
	Druid = 2,
	Sorcerer = 3,
	Paladin = 4,
	Knight = 5
}
local lastSpellCastAt = {}
local minHealFriendCastGapMs = 750
local healFriendThresholdSaveEvent
local SOURCE_PARTY = "party"
local CUSTOM_PLAYER_MAX = 50
local playerListWindow, configuredPlayersPanel, visiblePlayersPanel
local customPlayers = {}
local activePartyPlayers = {}
local refreshPlayerSettingsPanel, syncPartyPlayers, partySyncEvent

local function saveConfigIfReady()
	if ctx and ctx.isLoadingConfig and ctx.isLoadingConfig() then
		return
	end

	if ctx and ctx.saveConfig then
		ctx.saveConfig()
	end
end

local function cancelThresholdSave()
	if healFriendThresholdSaveEvent then
		removeEvent(healFriendThresholdSaveEvent)

		healFriendThresholdSaveEvent = nil
	end
end

local function flushThresholdSave()
	local hadPendingSave = healFriendThresholdSaveEvent ~= nil

	cancelThresholdSave()

	if hadPendingSave then
		saveConfigIfReady()
	end
end

local function scheduleThresholdSave()
	cancelThresholdSave()

	healFriendThresholdSaveEvent = scheduleEvent(function()
		healFriendThresholdSaveEvent = nil

		saveConfigIfReady()
	end, 250)
end

local HEAL_FRIEND_CHECK_IDS = {
	"enableHealFriendKnightCheckBox1",
	"enableHealFriendPaladinCheckBox1",
	"enableHealFriendSorcererCheckBox1",
	"enableHealFriendDruidCheckBox1",
	"enableHealFriendMonkCheckBox1",
	"enableHealFriendKnightCheckBox2",
	"enableHealFriendPaladinCheckBox2",
	"enableHealFriendSorcererCheckBox2",
	"enableHealFriendDruidCheckBox2",
	"enableHealFriendMonkCheckBox2",
	"enableHealFriendKnightCheckBox3",
	"enableHealFriendPaladinCheckBox3",
	"enableHealFriendSorcererCheckBox3",
	"enableHealFriendDruidCheckBox3",
	"enableHealFriendMonkCheckBox3"
}
local HEAL_FRIEND_PRIORITY_IDS = {
	"priorityKnightEdit1",
	"priorityPaladinEdit1",
	"prioritySorcererEdit1",
	"priorityDruidEdit1",
	"priorityMonkEdit1",
	"priorityKnightEdit2",
	"priorityPaladinEdit2",
	"prioritySorcererEdit2",
	"priorityDruidEdit2",
	"priorityMonkEdit2",
	"priorityKnightEdit3",
	"priorityPaladinEdit3",
	"prioritySorcererEdit3",
	"priorityDruidEdit3",
	"priorityMonkEdit3"
}
local LEGACY_HEAL_FRIEND_THRESHOLD_IDS = {
	"friendThresholdEdit1",
	"friendThresholdEdit2",
	"friendThresholdEdit3"
}
local HEAL_FRIEND_CONDITION_IDS = {
	"friendConditionComboBox1",
	"friendConditionComboBox2",
	"friendConditionComboBox3"
}
local HEAL_FRIEND_VOCATION_THRESHOLD_IDS = {}

for panelIdx = 1, 3 do
	for _, classKey in ipairs(CLASS_KEYS) do
		table.insert(HEAL_FRIEND_VOCATION_THRESHOLD_IDS, "friendThreshold" .. classKey .. "Edit" .. panelIdx)
	end
end

local THRESHOLD_MIN = 1
local THRESHOLD_MAX = 99
local THRESHOLD_DEFAULT = 80
local THRESHOLD_STEP = 1
local THRESHOLD_AUTO_PRESS_DELAY = 350
local PRIORITY_MIN = 0
local PRIORITY_MAX = 9

local function clampPriority(value)
	value = tonumber(value)

	if not value then
		return 9
	end

	return math.max(PRIORITY_MIN, math.min(PRIORITY_MAX, value))
end

local function getPriorityValueWidget(stepper)
	if not stepper then
		return nil
	end

	local numberBox = stepper:getChildById("numberBox")

	if not numberBox then
		return nil
	end

	for _, child in ipairs(numberBox:getChildren()) do
		return child
	end

	return nil
end

function HelperHealFriend.refreshPriorityStepper(stepper, valueWidget)
	if not stepper then
		return
	end

	local btnDec = stepper:getChildById("btnDec")
	local btnInc = stepper:getChildById("btnInc")

	valueWidget = valueWidget or getPriorityValueWidget(stepper)

	if not valueWidget or not btnDec or not btnInc then
		return
	end

	local value = clampPriority(valueWidget:getText())

	valueWidget:setText(tostring(value))
	btnDec:setEnabled(value > PRIORITY_MIN)
	btnInc:setEnabled(value < PRIORITY_MAX)
end

function HelperHealFriend.refreshAllPrioritySteppers()
	for _, id in ipairs(HEAL_FRIEND_PRIORITY_IDS) do
		local valueWidget = ctx.getWidget(id)

		if valueWidget then
			local numberBox = valueWidget:getParent()
			local stepper = numberBox and numberBox:getParent()

			HelperHealFriend.refreshPriorityStepper(stepper, valueWidget)
		end
	end
end

function HelperHealFriend.setupPriorityStepper(stepper, valueId, defaultValue)
	if not stepper then
		return
	end

	local valueWidget = stepper:recursiveGetChildById("numberValue")

	if valueWidget then
		valueWidget:setId(valueId)

		if defaultValue ~= nil then
			local current = valueWidget:getText()

			if current == "" or current == "0" then
				valueWidget:setText(tostring(defaultValue))
			end
		end
	end

	HelperHealFriend.refreshPriorityStepper(stepper, ctx.getWidget(valueId) or valueWidget)
end

function HelperHealFriend.onPriorityClick(widget, action)
	local stepper = widget and widget:getParent()

	if not stepper then
		return
	end

	local valueWidget = getPriorityValueWidget(stepper)

	if not valueWidget then
		return
	end

	local value = clampPriority(valueWidget:getText())

	if action == "dec" then
		value = math.max(PRIORITY_MIN, value - 1)
	elseif action == "inc" then
		value = math.min(PRIORITY_MAX, value + 1)
	end

	valueWidget:setText(tostring(value))
	HelperHealFriend.refreshPriorityStepper(stepper, valueWidget)
	saveConfigIfReady()
end

local helperCooldowns = {
	spells = {},
	groups = {}
}
local gameEventsConnected = false

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

local function sanitizePlayerThresholds(values)
	values = type(values) == "table" and values or {}

	local thresholds = {}

	for panelIdx = 1, 3 do
		thresholds[tostring(panelIdx)] = clampThreshold(values[tostring(panelIdx)] or values[panelIdx] or THRESHOLD_DEFAULT)
	end

	return thresholds
end

local function getCustomPlayerThreshold(entry, panelIdx)
	if type(entry) ~= "table" then
		return THRESHOLD_DEFAULT
	end

	entry.thresholds = sanitizePlayerThresholds(entry.thresholds)

	return entry.thresholds[tostring(panelIdx)]
end

local function setCustomPlayerThreshold(entry, panelIdx, value)
	if type(entry) ~= "table" then
		return
	end

	entry.thresholds = sanitizePlayerThresholds(entry.thresholds)
	entry.thresholds[tostring(panelIdx)] = clampThreshold(value)
end

local function trimText(value)
	return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizePlayerName(value)
	local name = trimText(value)

	if name == "" then
		return nil
	end

	return name:lower()
end

local function copyPlainTable(value)
	if type(value) ~= "table" then
		return nil
	end

	local copy = {}

	for key, item in pairs(value) do
		if type(item) == "table" then
			copy[key] = copyPlainTable(item)
		elseif type(item) == "string" or type(item) == "number" or type(item) == "boolean" then
			copy[key] = item
		end
	end

	return copy
end

local function vocationThresholdId(classKey, panelIdx)
	return "friendThreshold" .. classKey .. "Edit" .. panelIdx
end

local function sanitizeThresholdDigits(text)
	return tostring(text or ""):gsub("%D", "")
end

local function compareNumber(value, threshold, cond)
	if cond == "<=" then
		return value <= threshold
	end

	return value < threshold
end

local function getPanelThreshold(panelIdx)
	local w = ctx.getWidget("friendThresholdEdit" .. panelIdx)
	local text = w and w:getText() or ""

	if text == "" then
		return THRESHOLD_DEFAULT
	end

	return clampThreshold(text)
end

function HelperHealFriend.onThresholdChange(edit)
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

function HelperHealFriend.onThresholdFocusChange(edit, focused)
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

local function anchorRowWidget(widget, leftMargin)
	if not widget then
		return
	end

	widget:breakAnchors()
	widget:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
	widget:addAnchor(AnchorLeft, "parent", AnchorLeft)
	widget:setMarginLeft(leftMargin)
	widget:setMarginTop(0)
end

local function getThresholdStepperValueLabel(stepper)
	if not stepper then
		return nil
	end

	local valueLabel = stepper:recursiveGetChildById("numberValue")

	if not valueLabel then
		local numberBox = stepper:recursiveGetChildById("numberBox")

		if numberBox then
			for _, child in ipairs(numberBox:getChildren()) do
				valueLabel = child

				break
			end
		end
	end

	return valueLabel
end

local function refreshThresholdStepper(stepper)
	local valueLabel = getThresholdStepperValueLabel(stepper)

	if not valueLabel then
		return
	end

	local value = clampThreshold(valueLabel:getText())

	valueLabel:setText(tostring(value))

	local decrementButton = stepper:recursiveGetChildById("btnDec")

	if decrementButton then
		decrementButton:setEnabled(value > THRESHOLD_MIN)
	end

	local incrementButton = stepper:recursiveGetChildById("btnInc")

	if incrementButton then
		incrementButton:setEnabled(value < THRESHOLD_MAX)
	end
end

local function applyThresholdStepperDelta(stepper, delta, onChanged)
	local valueLabel = getThresholdStepperValueLabel(stepper)

	if not valueLabel then
		return
	end

	local value = clampThreshold(clampThreshold(valueLabel:getText()) + delta)

	valueLabel:setText(tostring(value))
	refreshThresholdStepper(stepper)

	if onChanged then
		onChanged(value)
	end

	scheduleThresholdSave()
end

local function bindThresholdStepperButton(button, stepper, delta, onChanged)
	if not button then
		return
	end

	if g_mouse and g_mouse.bindAutoPress then
		g_mouse.bindAutoPress(button, function()
			applyThresholdStepperDelta(stepper, delta, onChanged)
		end, THRESHOLD_AUTO_PRESS_DELAY)
	else
		function button.onClick()
			applyThresholdStepperDelta(stepper, delta, onChanged)
		end
	end

	function button.onMouseRelease(_, _, mouseButton)
		if mouseButton == MouseLeftButton then
			flushThresholdSave()
		end

		return false
	end
end

local function setupVocationThresholdControls()
	for panelIdx = 1, 3 do
		local legacyThreshold = ctx.getWidget("friendThresholdEdit" .. panelIdx)
		local legacyDefault = legacyThreshold and clampThreshold(legacyThreshold:getText()) or THRESHOLD_DEFAULT

		if legacyThreshold then
			legacyThreshold:hide()

			local legacyPercent = legacyThreshold:getParent():getChildAfter(legacyThreshold)

			if legacyPercent then
				legacyPercent:hide()
			end
		end

		for _, classKey in ipairs(CLASS_KEYS) do
			local row = ctx.getWidget("sio" .. classKey .. "Panel" .. panelIdx)
			local priorityId = "priority" .. classKey .. "Edit" .. panelIdx
			local decrementButton = row and row:recursiveGetChildById("btnDec") or nil
			local stepper = decrementButton and decrementButton:getParent() or nil

			if row and stepper then
				HelperHealFriend.setupPriorityStepper(stepper, priorityId, DEFAULT_PRIORITY_BY_CLASS[classKey])

				local priorityValue = ctx.getWidget(priorityId) or getPriorityValueWidget(stepper)
				local priorityLabel = stepper and row:getChildBefore(stepper) or nil

				if priorityValue then
					row:setWidth(270)
					row:setHeight(18)

					local thresholdId = vocationThresholdId(classKey, panelIdx)
					local thresholdStepperId = "friendThreshold" .. classKey .. "Stepper" .. panelIdx
					local thresholdStepper = ctx.getWidget(thresholdStepperId)

					if not thresholdStepper then
						thresholdStepper = g_ui.createWidget("HealingPercentStepper", row)

						thresholdStepper:setId(thresholdStepperId)
						thresholdStepper:setHeight(18)

						local valueLabel = thresholdStepper:recursiveGetChildById("numberValue")

						if valueLabel then
							valueLabel:setId(thresholdId)
							valueLabel:setText(tostring(legacyDefault))
						end

						bindThresholdStepperButton(thresholdStepper:recursiveGetChildById("btnDec"), thresholdStepper, -THRESHOLD_STEP)
						bindThresholdStepperButton(thresholdStepper:recursiveGetChildById("btnInc"), thresholdStepper, THRESHOLD_STEP)
					end

					thresholdStepper:show()
					anchorRowWidget(thresholdStepper, 76)
					refreshThresholdStepper(thresholdStepper)

					local percentId = "friendThreshold" .. classKey .. "Percent" .. panelIdx
					local percent = ctx.getWidget(percentId)

					if not percent then
						percent = g_ui.createWidget("HealFriendVocationThresholdPercent", row)

						percent:setId(percentId)
					end

					percent:show()
					anchorRowWidget(percent, 135)
					anchorRowWidget(priorityLabel, 150)
					anchorRowWidget(stepper, 197)
				end
			end
		end
	end
end

local function refreshAllThresholdSteppers()
	for panelIdx = 1, 3 do
		for _, classKey in ipairs(CLASS_KEYS) do
			refreshThresholdStepper(ctx.getWidget("friendThreshold" .. classKey .. "Stepper" .. panelIdx))
		end
	end
end

local function updateTargetingUi()
	local portuguese = ctx and ctx.getLanguage and ctx.getLanguage() == "pt"
	local layout = HEAL_FRIEND_PANEL_BY_VOC[ctx.getPlayerVoc()] or {
		false,
		false,
		false
	}
	local hasAvailableSpell = layout[1] or layout[2] or layout[3]

	for panelIdx = 1, 3 do
		local panel = ctx.getWidget("mainPanel" .. panelIdx)

		if panel then
			panel:setVisible(false)
		end
	end

	local playerModePanel = ctx.getWidget("healFriendPlayerModePanel")

	if playerModePanel then
		playerModePanel:setVisible(hasAvailableSpell)
	end

	local playerCount = ctx and ctx.getWidget("friendPlayerCountLabel") or nil

	if playerCount then
		playerCount:setText(string.format("%s: %d", portuguese and "Jogadores no grupo" or "Party players", #activePartyPlayers))
	end

	if hasAvailableSpell and refreshPlayerSettingsPanel then
		refreshPlayerSettingsPanel()
	end
end

local function onSpellCooldownEvt(spellId, delay)
	helperCooldowns.spells[Spells.resolveSpellId(spellId)] = g_clock.millis() + delay
end

local function onSpellGroupCooldownEvt(groupId, delay)
	helperCooldowns.groups[groupId] = g_clock.millis() + delay
end

local function cancelPartySync()
	if partySyncEvent then
		removeEvent(partySyncEvent)

		partySyncEvent = nil
	end
end

local function schedulePartySync(delay)
	cancelPartySync()

	partySyncEvent = scheduleEvent(function()
		partySyncEvent = nil

		if syncPartyPlayers then
			syncPartyPlayers()
		end
	end, delay or 50)
end

local function onPartyCreatureChanged(creature)
	if creature and creature.isPlayer and creature:isPlayer() then
		schedulePartySync()
	end
end

local function onHealFriendGameStart()
	schedulePartySync(250)
end

local function onHealFriendGameEnd()
	cancelPartySync()

	activePartyPlayers = {}

	if refreshPlayerSettingsPanel then
		refreshPlayerSettingsPanel()
	end

	updateTargetingUi()
end

local function isSpellOnCooldown(words)
	local spell = Spells.getSpellByWords and Spells.getSpellByWords(words)

	if not spell then
		return false
	end

	local now = g_clock.millis()

	if now < (helperCooldowns.spells[spell.id] or 0) then
		return true
	end

	if spell.group then
		for groupId in pairs(spell.group) do
			if now < (helperCooldowns.groups[groupId] or 0) then
				return true
			end
		end
	end

	return false
end

local function connectGameEvents()
	if gameEventsConnected then
		return
	end

	connect(g_game, {
		onSpellCooldown = onSpellCooldownEvt,
		onSpellGroupCooldown = onSpellGroupCooldownEvt,
		onGameStart = onHealFriendGameStart,
		onGameEnd = onHealFriendGameEnd
	})
	connect(Creature, {
		onShieldChange = onPartyCreatureChanged,
		onAppear = onPartyCreatureChanged,
		onDisappear = onPartyCreatureChanged,
		onOutfitChange = onPartyCreatureChanged
	})

	gameEventsConnected = true
end

local function disconnectGameEvents()
	if not gameEventsConnected then
		return
	end

	disconnect(g_game, {
		onSpellCooldown = onSpellCooldownEvt,
		onSpellGroupCooldown = onSpellGroupCooldownEvt,
		onGameStart = onHealFriendGameStart,
		onGameEnd = onHealFriendGameEnd
	})
	disconnect(Creature, {
		onShieldChange = onPartyCreatureChanged,
		onAppear = onPartyCreatureChanged,
		onDisappear = onPartyCreatureChanged,
		onOutfitChange = onPartyCreatureChanged
	})

	gameEventsConnected = false
end

local function isAllowedVocation()
	local voc = ctx.getPlayerVoc()

	return voc == 2 or voc == 6 or voc == 9 or voc == 10
end

local function hasPartyShield(creature)
	if not creature or not creature.getShield then
		return false
	end

	if CreatureList and CreatureList.isRemotePartyMember then
		return CreatureList.isRemotePartyMember(creature)
	end

	local shield = creature:getShield()

	return shield == ShieldYellow or shield == ShieldYellowSharedExp or shield == ShieldYellowNoSharedExpBlink or shield == ShieldYellowNoSharedExp or shield == ShieldBlue or shield == ShieldBlueSharedExp or shield == ShieldBlueNoSharedExpBlink or shield == ShieldBlueNoSharedExp
end

local function customPlayerOrder()
	local order = {}

	for index, entry in ipairs(customPlayers) do
		local key = normalizePlayerName(entry and entry.name)

		if key then
			order[key] = index
		end
	end

	return order
end

local function findCustomPlayerEntry(name)
	local wanted = normalizePlayerName(name)

	if not wanted then
		return nil, nil
	end

	for index, entry in ipairs(customPlayers) do
		if normalizePlayerName(entry and entry.name) == wanted then
			return entry, index
		end
	end

	return nil, nil
end

local function creatureDistance(fromPos, creature)
	local position = creature and creature.getPosition and creature:getPosition() or nil

	if not fromPos or not position or fromPos.z ~= position.z then
		return 99
	end

	return math.max(math.abs(fromPos.x - position.x), math.abs(fromPos.y - position.y))
end

local function buildPartyCandidates(localPos)
	local listOrder = customPlayerOrder()
	local candidates = {}

	for _, creature in ipairs(g_map.getSpectators(localPos, false) or {}) do
		if creature and creature:isPlayer() and not creature:isLocalPlayer() then
			local name = creature:getName() or ""
			local normalizedName = normalizePlayerName(name)
			local allowed = hasPartyShield(creature) and normalizedName and listOrder[normalizedName] ~= nil

			if allowed then
				table.insert(candidates, {
					creature = creature,
					distance = creatureDistance(localPos, creature),
					name = normalizedName or "",
					listOrder = listOrder[normalizedName]
				})
			end
		end
	end

	table.sort(candidates, function(a, b)
		if a.listOrder ~= b.listOrder then
			return (a.listOrder or CUSTOM_PLAYER_MAX + 1) < (b.listOrder or CUSTOM_PLAYER_MAX + 1)
		end

		if a.distance ~= b.distance then
			return a.distance < b.distance
		end

		return a.name < b.name
	end)

	local selected = {}

	for index = 1, #candidates do
		table.insert(selected, candidates[index].creature)
	end

	return selected
end

local function getSpellWordsByPanel(panelIdx)
	local cfg = SPELLS_BY_PANEL[panelIdx]

	if not cfg then
		return nil
	end

	local byId = Spells and Spells.getSpellByClientId and Spells.getSpellByClientId(cfg.id) or nil

	if byId and byId.words and byId.words ~= "" then
		return byId.words
	end

	return cfg.words
end

local function findVisiblePlayerByName(name)
	local wanted = normalizePlayerName(name)
	local localPlayer = g_game.getLocalPlayer()
	local position = localPlayer and localPlayer:getPosition() or nil

	if not wanted or not position then
		return nil
	end

	for _, creature in ipairs(g_map.getSpectators(position, false) or {}) do
		if creature and creature:isPlayer() and not creature:isLocalPlayer() and normalizePlayerName(creature:getName()) == wanted then
			return creature
		end
	end

	return nil
end

local function sanitizeCustomPlayers(players)
	local result = {}
	local seen = {}

	for _, raw in ipairs(type(players) == "table" and players or {}) do
		local name = type(raw) == "table" and raw.name or raw

		name = trimText(name)

		local key = normalizePlayerName(name)

		if key and not seen[key] and #result < CUSTOM_PLAYER_MAX then
			seen[key] = true

			table.insert(result, {
				name = name,
				outfit = type(raw) == "table" and copyPlainTable(raw.outfit) or nil,
				thresholds = sanitizePlayerThresholds(type(raw) == "table" and (raw.thresholds or raw.spellThresholds) or nil),
				enabled = type(raw) ~= "table" or raw.enabled ~= false
			})
		end
	end

	return result
end

local function addCustomPlayer(name, outfit)
	name = trimText(name)

	local key = normalizePlayerName(name)

	if not key then
		return false
	end

	for _, entry in ipairs(customPlayers) do
		if normalizePlayerName(entry.name) == key then
			if outfit then
				entry.name = name
				entry.outfit = copyPlainTable(outfit)

				return true
			end

			return false
		end
	end

	if #customPlayers >= CUSTOM_PLAYER_MAX then
		return false
	end

	table.insert(customPlayers, {
		enabled = true,
		name = name,
		outfit = copyPlainTable(outfit),
		thresholds = sanitizePlayerThresholds(nil)
	})

	return true
end

local function collectPartyMembers()
	local byName = {}

	local function addCreature(creature, trustedPartyMember)
		if not creature or not trustedPartyMember and not hasPartyShield(creature) then
			return
		end

		local key = normalizePlayerName(creature:getName())

		if key and not byName[key] then
			byName[key] = creature
		end
	end

	local partyModule = modules and modules.game_party or nil
	local partyManager = partyModule and partyModule.PartyListManager or nil

	for _, instance in pairs(partyManager and partyManager.instances or {}) do
		for _, button in pairs(instance.battleButtons or {}) do
			addCreature(button and button.creature or nil, true)
		end
	end

	local partyRegistry = partyModule and partyModule.PartyListRegistry or nil

	if partyRegistry and type(partyRegistry.byId) == "table" then
		for _, creature in pairs(partyRegistry.byId) do
			addCreature(creature)
		end
	end

	local localPlayer = g_game.getLocalPlayer()
	local position = localPlayer and localPlayer:getPosition() or nil

	if position then
		for _, creature in ipairs(g_map.getSpectators(position, false) or {}) do
			addCreature(creature)
		end
	end

	local members = {}

	for _, creature in pairs(byName) do
		table.insert(members, creature)
	end

	table.sort(members, function(a, b)
		return (a:getName() or ""):lower() < (b:getName() or ""):lower()
	end)

	return members, byName
end

function syncPartyPlayers(refreshUi)
	local members, activeByName = collectPartyMembers()
	local addedPlayer = false

	for _, creature in ipairs(members) do
		local entry = findCustomPlayerEntry(creature:getName())

		if not entry then
			if addCustomPlayer(creature:getName(), creature:getOutfit()) then
				addedPlayer = true
			end
		else
			entry.name = creature:getName()
			entry.outfit = copyPlainTable(creature:getOutfit())
		end
	end

	activePartyPlayers = {}

	for _, entry in ipairs(customPlayers) do
		local key = normalizePlayerName(entry and entry.name)

		if key and activeByName[key] then
			table.insert(activePartyPlayers, entry)
		end
	end

	if addedPlayer then
		saveConfigIfReady()
	end

	if refreshUi ~= false then
		updateTargetingUi()
	end
end

local function populatePlayerRow(row, name, outfit)
	if not row then
		return
	end

	local nameLabel = row:recursiveGetChildById("playerName")

	if nameLabel then
		nameLabel:setText(name or "")

		if nameLabel.setTooltip then
			nameLabel:setTooltip(name or "")
		end
	end

	local outfitWidget = row:recursiveGetChildById("playerOutfit")

	if outfitWidget then
		if outfit then
			outfitWidget:setOutfit(outfit)
			outfitWidget:show()

			local creature = outfitWidget:getCreature()

			if creature and creature.setDirection then
				creature:setDirection(South)
			end
		else
			outfitWidget:hide()
		end
	end
end

function HelperHealFriend.destroyPlayerPriorityDragGhost()
	if HelperHealFriend.playerPriorityDragGhost and not HelperHealFriend.playerPriorityDragGhost:isDestroyed() then
		HelperHealFriend.playerPriorityDragGhost:destroy()
	end

	HelperHealFriend.playerPriorityDragGhost = nil
end

function HelperHealFriend.updatePlayerPriorityDragGhostPosition(mousePos)
	local ghost = HelperHealFriend.playerPriorityDragGhost

	if not ghost or ghost:isDestroyed() or not mousePos then
		return
	end

	local size = ghost:getSize()
	local width = size and size.width or 260
	local height = size and size.height or 36

	ghost:setPosition({
		x = mousePos.x - math.floor(width / 2),
		y = mousePos.y - math.floor(height / 2)
	})
	ghost:raise()
end

function HelperHealFriend.updatePlayerPriorityDragGhost(row, entry, mousePos)
	if not entry then
		return
	end

	local ghost = HelperHealFriend.playerPriorityDragGhost

	if not ghost or ghost:isDestroyed() then
		local root = g_ui.getRootWidget()

		if not root then
			return
		end

		ghost = g_ui.createWidget("HealFriendPlayerDragGhost", root)
		HelperHealFriend.playerPriorityDragGhost = ghost

		ghost:setId("healFriendPlayerPriorityDragGhost")
		ghost:setPhantom(true)
		ghost:setFocusable(false)
		ghost:setDraggable(false)

		if ctx and ctx.applyWidgetLanguage then
			ctx.applyWidgetLanguage(ghost)
		end
	end

	if row and row.getWidth then
		ghost:setWidth(math.max(260, row:getWidth()))
	end

	populatePlayerRow(ghost, entry.name, entry.outfit)
	ghost:setVisible(true)
	HelperHealFriend.updatePlayerPriorityDragGhostPosition(mousePos or g_window.getMousePosition())
end

function HelperHealFriend.setPlayerPriorityDragSourceVisual(row, dragging)
	if not row or row:isDestroyed() then
		return
	end

	if dragging then
		row:setOpacity(0.45)
		row:setBackgroundColor("#6a6a6a")

		return
	end

	row:setOpacity(1)
	row:setBackgroundColor(row.zebraColor or "#414141")
end

local function reorderPartyPlayerByDrop(sourceKey, targetKey, afterTarget)
	sourceKey = normalizePlayerName(sourceKey)
	targetKey = normalizePlayerName(targetKey)

	if not sourceKey or sourceKey == targetKey then
		return nil
	end

	local sourceEntry, sourceIndex = findCustomPlayerEntry(sourceKey)

	if not sourceEntry or not sourceIndex then
		return nil
	end

	if targetKey and not findCustomPlayerEntry(targetKey) then
		return nil
	end

	table.remove(customPlayers, sourceIndex)

	if targetKey then
		local _, targetIndex = findCustomPlayerEntry(targetKey)

		if not targetIndex then
			table.insert(customPlayers, sourceIndex, sourceEntry)

			return nil
		end

		local insertIndex = targetIndex + (afterTarget and 1 or 0)

		table.insert(customPlayers, math.max(1, math.min(insertIndex, #customPlayers + 1)), sourceEntry)
	else
		table.insert(customPlayers, sourceEntry)
	end

	return sourceKey
end

local function finishPartyPlayerDrop(playerKey)
	HelperHealFriend.destroyPlayerPriorityDragGhost()
	saveConfigIfReady()
	addEvent(function()
		if syncPartyPlayers then
			syncPartyPlayers()
		end

		local list = ctx and ctx.getWidget("healFriendPlayerSettingsList") or nil

		if list then
			for _, row in ipairs(list:getChildren()) do
				if row.healFriendPlayerKey == playerKey then
					row:focus()

					break
				end
			end
		end
	end)
end

local function dropPartyPlayerOnRow(targetRow, draggedWidget, mousePos, forcedAfterTarget)
	if not targetRow or not draggedWidget or not draggedWidget.healFriendPlayerKey or not targetRow.healFriendPlayerKey then
		return false
	end

	local afterTarget = forcedAfterTarget

	if afterTarget == nil then
		afterTarget = mousePos and mousePos.y >= targetRow:getY() + targetRow:getHeight() / 2
	end

	local playerKey = reorderPartyPlayerByDrop(draggedWidget.healFriendPlayerKey, targetRow.healFriendPlayerKey, afterTarget)

	if not playerKey then
		return false
	end

	HelperHealFriend.setPlayerPriorityDragSourceVisual(draggedWidget._healFriendPriorityRow or draggedWidget, false)
	finishPartyPlayerDrop(playerKey)

	return true
end

local function dropPartyPlayerOnPanel(panel, draggedWidget)
	if not panel or not draggedWidget or not draggedWidget.healFriendPlayerKey then
		return false
	end

	local playerKey = reorderPartyPlayerByDrop(draggedWidget.healFriendPlayerKey, nil, false)

	if not playerKey then
		return false
	end

	HelperHealFriend.setPlayerPriorityDragSourceVisual(draggedWidget._healFriendPriorityRow or draggedWidget, false)
	finishPartyPlayerDrop(playerKey)

	return true
end

local function isMouseInsidePartyPlayerList(list, mousePos)
	if not list or list:isDestroyed() or not mousePos then
		return false
	end

	if list.containsPaddingPoint then
		return list:containsPaddingPoint(mousePos)
	end

	return mousePos.x >= list:getX() and mousePos.x <= list:getX() + list:getWidth() and mousePos.y >= list:getY() and mousePos.y <= list:getY() + list:getHeight()
end

function HelperHealFriend.dropPartyPlayerAtMouse(fallbackRow, draggedWidget, mousePos)
	if not draggedWidget or not draggedWidget.healFriendPlayerKey then
		return false
	end

	local list = ctx and ctx.getWidget("healFriendPlayerSettingsList") or nil

	if list and isMouseInsidePartyPlayerList(list, mousePos) then
		local lastRow

		for _, row in ipairs(list:getChildren()) do
			if row:isVisible() and row.healFriendPlayerKey then
				lastRow = row

				if mousePos.y < row:getY() + row:getHeight() / 2 then
					return dropPartyPlayerOnRow(row, draggedWidget, mousePos, false)
				end
			end
		end

		if lastRow then
			return dropPartyPlayerOnRow(lastRow, draggedWidget, mousePos, true)
		end

		return dropPartyPlayerOnPanel(list, draggedWidget)
	end

	if fallbackRow then
		return dropPartyPlayerOnRow(fallbackRow, draggedWidget, mousePos)
	end

	return false
end

local function bindPartyPlayerDropForwarder(widget, row)
	if not widget then
		return
	end

	local previousOnDrop = widget.onDrop

	function widget:onDrop(draggedWidget, mousePos)
		if draggedWidget and draggedWidget.healFriendPlayerKey then
			return HelperHealFriend.dropPartyPlayerAtMouse(row, draggedWidget, mousePos)
		end

		if previousOnDrop then
			return previousOnDrop(self, draggedWidget, mousePos)
		end

		return false
	end

	for _, child in ipairs(widget:getChildren()) do
		bindPartyPlayerDropForwarder(child, row)
	end
end

local function bindPartyPlayerDragSource(widget, row, entry)
	if not widget or not row or not entry then
		return
	end

	widget.healFriendPlayerKey = row.healFriendPlayerKey
	widget._healFriendPriorityRow = row

	widget:setDraggable(true)
	widget:setPhantom(false)

	function widget:onDragEnter(mousePos)
		local sourceRow = self._healFriendPriorityRow or row
		local current = findCustomPlayerEntry(self.healFriendPlayerKey) or entry

		HelperHealFriend.updatePlayerPriorityDragGhost(sourceRow, current, mousePos)
		HelperHealFriend.setPlayerPriorityDragSourceVisual(sourceRow, true)

		return true
	end

	function widget.onDragMove(_, mousePos)
		HelperHealFriend.updatePlayerPriorityDragGhostPosition(mousePos)

		return true
	end

	function widget:onDragLeave()
		local sourceRow = self._healFriendPriorityRow or row

		HelperHealFriend.destroyPlayerPriorityDragGhost()

		if not sourceRow:isDestroyed() then
			HelperHealFriend.setPlayerPriorityDragSourceVisual(sourceRow, false)
		end

		return true
	end
end

local function bindPartyPlayerDrag(row, entry)
	if not row or not entry then
		return
	end

	row.healFriendPlayerKey = normalizePlayerName(entry.name)
	row._healFriendPriorityRow = row

	bindPartyPlayerDragSource(row, row, entry)
	bindPartyPlayerDragSource(row:recursiveGetChildById("playerOutfit"), row, entry)
	bindPartyPlayerDragSource(row:recursiveGetChildById("playerName"), row, entry)

	function row:onDrop(draggedWidget, mousePos)
		return HelperHealFriend.dropPartyPlayerAtMouse(self, draggedWidget, mousePos)
	end

	bindPartyPlayerDropForwarder(row, row)
end

local function getActiveSpellPanels()
	local result = {}
	local layout = HEAL_FRIEND_PANEL_BY_VOC[ctx.getPlayerVoc()] or {
		false,
		false,
		false
	}

	for panelIdx = 1, 3 do
		if layout[panelIdx] then
			table.insert(result, panelIdx)
		end
	end

	return result
end

function refreshPlayerSettingsPanel()
	local list = ctx and ctx.getWidget("healFriendPlayerSettingsList") or nil

	if not list or list:isDestroyed() then
		return
	end

	function list.onDrop(_, draggedWidget, mousePos)
		return HelperHealFriend.dropPartyPlayerAtMouse(nil, draggedWidget, mousePos)
	end

	local spellPanels = getActiveSpellPanels()
	local columns = #spellPanels == 1 and {
		255
	} or {
		200,
		310
	}

	for columnIndex = 1, 2 do
		local header = ctx.getWidget("friendPlayerSpellHeader" .. columnIndex)
		local separator = ctx.getWidget("friendPlayerSpellHeaderSeparator" .. columnIndex)
		local panelIdx = spellPanels[columnIndex]

		if header then
			if panelIdx and SPELLS_BY_PANEL[panelIdx] then
				local separatorMargin = columns[columnIndex] - 9

				header:setText(SPELLS_BY_PANEL[panelIdx].label)
				header:setMarginLeft(separatorMargin + 3)

				if columnIndex == 1 then
					header:setWidth(100)
				end

				header:show()

				if separator then
					separator:setMarginLeft(separatorMargin)
					separator:show()
				end
			else
				header:hide()

				if separator then
					separator:hide()
				end
			end
		end
	end

	list:destroyChildren()

	for playerIndex, entry in ipairs(activePartyPlayers) do
		local row = g_ui.createWidget("HealFriendPlayerSettingsRow", list)

		row.zebraColor = playerIndex % 2 == 0 and "#414141" or "#484848"

		row:setBackgroundColor(row.zebraColor)
		populatePlayerRow(row, entry.name, entry.outfit)

		local enabledCheck = row:recursiveGetChildById("friendPlayerEnabledCheckBox")

		if enabledCheck then
			enabledCheck:setChecked(entry.enabled ~= false)

			function enabledCheck.onCheckChange(_, checked)
				entry.enabled = checked == true

				saveConfigIfReady()
			end
		end

		for columnIndex, panelIdx in ipairs(spellPanels) do
			local spellPanelIdx = panelIdx
			local separator = g_ui.createWidget("HelperListColumnSeparator", row)

			separator:breakAnchors()
			separator:addAnchor(AnchorTop, "parent", AnchorTop)
			separator:addAnchor(AnchorBottom, "parent", AnchorBottom)
			separator:addAnchor(AnchorLeft, "parent", AnchorLeft)
			separator:setMarginLeft(columns[columnIndex] - 10)

			local stepper = g_ui.createWidget("HealingPercentStepper", row)

			stepper:setId(string.format("friendPlayerThresholdStepper%d_%d", playerIndex, spellPanelIdx))
			stepper:setHeight(18)
			anchorRowWidget(stepper, columns[columnIndex])

			local valueLabel = getThresholdStepperValueLabel(stepper)

			if valueLabel then
				valueLabel:setId(string.format("friendPlayerThresholdValue%d_%d", playerIndex, spellPanelIdx))
				valueLabel:setText(tostring(getCustomPlayerThreshold(entry, spellPanelIdx)))
			end

			local function onThresholdChanged(value)
				setCustomPlayerThreshold(entry, spellPanelIdx, value)
			end

			bindThresholdStepperButton(stepper:recursiveGetChildById("btnDec"), stepper, -THRESHOLD_STEP, onThresholdChanged)
			bindThresholdStepperButton(stepper:recursiveGetChildById("btnInc"), stepper, THRESHOLD_STEP, onThresholdChanged)
			refreshThresholdStepper(stepper)

			local percent = g_ui.createWidget("HealFriendVocationThresholdPercent", row)

			percent:setId(string.format("friendPlayerThresholdPercent%d_%d", playerIndex, spellPanelIdx))
			anchorRowWidget(percent, columns[columnIndex] + 59)
		end

		bindPartyPlayerDrag(row, entry)
	end

	local emptyLabel = ctx.getWidget("friendPlayerSettingsEmptyLabel")

	if emptyLabel then
		emptyLabel:setVisible(#activePartyPlayers == 0)
		emptyLabel:raise()
	end
end

local function refreshConfiguredPlayersPanel()
	if not configuredPlayersPanel or configuredPlayersPanel:isDestroyed() then
		return
	end

	configuredPlayersPanel:destroyChildren()

	for index, entry in ipairs(customPlayers) do
		local row = g_ui.createWidget("HealFriendPlayerListRow", configuredPlayersPanel)

		row.customPlayerIndex = index

		populatePlayerRow(row, entry.name, entry.outfit)
	end
end

local function refreshVisiblePlayersPanel()
	if not visiblePlayersPanel or visiblePlayersPanel:isDestroyed() then
		return
	end

	visiblePlayersPanel:destroyChildren()

	local localPlayer = g_game.getLocalPlayer()
	local position = localPlayer and localPlayer:getPosition() or nil
	local visible = {}

	if position then
		for _, creature in ipairs(g_map.getSpectators(position, false) or {}) do
			if creature and creature:isPlayer() and not creature:isLocalPlayer() then
				table.insert(visible, creature)
			end
		end
	end

	table.sort(visible, function(a, b)
		return (a:getName() or ""):lower() < (b:getName() or ""):lower()
	end)

	for _, creature in ipairs(visible) do
		local row = g_ui.createWidget("HealFriendPlayerListRow", visiblePlayersPanel)

		row.visiblePlayerName = creature:getName()
		row.visiblePlayerOutfit = copyPlainTable(creature:getOutfit())

		populatePlayerRow(row, row.visiblePlayerName, row.visiblePlayerOutfit)
	end
end

local function refreshPlayerListWindow()
	refreshConfiguredPlayersPanel()
	refreshVisiblePlayersPanel()
	updateTargetingUi()
end

local function closePlayerListWindow()
	if playerListWindow and not playerListWindow:isDestroyed() then
		playerListWindow:destroy()
	end

	playerListWindow = nil
	configuredPlayersPanel = nil
	visiblePlayersPanel = nil
end

function HelperHealFriend.openPlayerListWindow()
	closePlayerListWindow()

	playerListWindow = g_ui.loadUI("assign_heal_friend_players", g_ui.getRootWidget())

	if not playerListWindow then
		return
	end

	if ctx and ctx.applyWidgetLanguage then
		ctx.applyWidgetLanguage(playerListWindow)
	end

	configuredPlayersPanel = playerListWindow:recursiveGetChildById("configuredPlayersPanel")
	visiblePlayersPanel = playerListWindow:recursiveGetChildById("visiblePlayersPanel")

	refreshPlayerListWindow()
	playerListWindow:raise()
	playerListWindow:focus()

	local edit = playerListWindow:recursiveGetChildById("playerNameEdit")

	if edit then
		edit:focus()
	end
end

function HelperHealFriend.closePlayerListWindow()
	closePlayerListWindow()
end

function HelperHealFriend.addTypedPlayer()
	if not playerListWindow or playerListWindow:isDestroyed() then
		return
	end

	local edit = playerListWindow:recursiveGetChildById("playerNameEdit")
	local name = edit and trimText(edit:getText()) or ""

	if name == "" then
		return
	end

	local visible = findVisiblePlayerByName(name)

	if visible then
		name = visible:getName()
	end

	local changed = addCustomPlayer(name, visible and visible:getOutfit() or nil)

	if edit then
		edit:setText("")
	end

	if changed then
		saveConfigIfReady()
	end

	refreshPlayerListWindow()
end

function HelperHealFriend.addVisiblePlayer()
	if not visiblePlayersPanel or visiblePlayersPanel:isDestroyed() then
		return
	end

	local row = visiblePlayersPanel:getFocusedChild()

	if not row or not row.visiblePlayerName then
		return
	end

	if addCustomPlayer(row.visiblePlayerName, row.visiblePlayerOutfit) then
		saveConfigIfReady()
	end

	refreshPlayerListWindow()
end

function HelperHealFriend.removeConfiguredPlayer()
	if not configuredPlayersPanel or configuredPlayersPanel:isDestroyed() then
		return
	end

	local row = configuredPlayersPanel:getFocusedChild()
	local index = row and tonumber(row.customPlayerIndex) or nil

	if not index or not customPlayers[index] then
		return
	end

	table.remove(customPlayers, index)
	saveConfigIfReady()
	refreshPlayerListWindow()
end

function HelperHealFriend.refreshVisiblePlayers()
	refreshVisiblePlayersPanel()
end

function HelperHealFriend.applyVocationGate()
	local allowed = isAllowedVocation()
	local healFriendFrame = ctx.getWidget("healFriendFrame")
	local healFriendBtn = ctx.getWidget("healFriend")
	local targetButtonFrame = ctx.getWidget("targetButtonFrame")

	if healFriendFrame then
		if allowed then
			healFriendFrame:setVisible(true)
			healFriendFrame:setHeight(24)
			healFriendFrame:setMarginTop(11)
		else
			healFriendFrame:setVisible(false)
			healFriendFrame:setHeight(0)
			healFriendFrame:setMarginTop(0)
		end
	end

	if targetButtonFrame then
		targetButtonFrame:setMarginTop(allowed and 11 or 12)
	end

	if healFriendBtn then
		if allowed then
			healFriendBtn:setVisible(true)
			healFriendBtn:setHeight(22)
		else
			healFriendBtn:setVisible(false)
			healFriendBtn:setHeight(0)
		end
	end

	if not allowed then
		local enableCheck = ctx.getWidget("enableHealFriendCheckBox")

		if enableCheck then
			enableCheck:setChecked(false)
		end

		local healFriendBtn2 = ctx.getWidget("healFriend")

		if healFriendBtn2 and healFriendBtn2:isOn() and modules.game_helper then
			modules.game_helper.showTab("healing")
		end
	end

	updateTargetingUi()
	HelperHealFriend.refreshAllPrioritySteppers()
end

function HelperHealFriend.runTick(state)
	if not isAllowedVocation() then
		return false
	end

	local helperEnabled = ctx.getWidget("checkbox")
	local healFriendEnabled = ctx.getWidget("enableHealFriendCheckBox")

	if not helperEnabled or not helperEnabled:isChecked() then
		return false
	end

	if not healFriendEnabled or not healFriendEnabled:isChecked() then
		return false
	end

	local localPlayer = state.player

	if not localPlayer then
		return false
	end

	local localPos = localPlayer:getPosition()

	if not localPos then
		return false
	end

	local candidates = buildPartyCandidates(localPos)
	local nowMs = state.nowMs or g_clock.millis()

	for panelIdx = 1, 3 do
		local panelEnabled = HEAL_FRIEND_PANEL_BY_VOC[ctx.getPlayerVoc()] or {
			false,
			false,
			false
		}

		if panelEnabled[panelIdx] then
			local words = getSpellWordsByPanel(panelIdx)

			if words and words ~= "" then
				local spellKey = tostring(panelIdx)

				if nowMs >= (lastSpellCastAt[spellKey] or 0) and not isSpellOnCooldown(words) then
					local ranked = {}

					for _, creature in ipairs(candidates) do
						if creature and creature:isPlayer() and not creature:isLocalPlayer() then
							local hp = creature:getHealthPercent()

							if hp and hp > 0 then
								local entry, listOrder = findCustomPlayerEntry(creature:getName())

								if entry and entry.enabled ~= false and compareNumber(hp, getCustomPlayerThreshold(entry, panelIdx), "<=") then
									table.insert(ranked, {
										creature = creature,
										hp = hp,
										listOrder = listOrder
									})
								end
							end
						end
					end

					table.sort(ranked, function(a, b)
						if a.listOrder ~= b.listOrder then
							return (a.listOrder or CUSTOM_PLAYER_MAX + 1) < (b.listOrder or CUSTOM_PLAYER_MAX + 1)
						end

						return a.hp < b.hp
					end)

					local target = ranked[1] and ranked[1].creature or nil

					if target then
						g_game.talk(string.format("%s \"%s\"", words, target:getName()))

						lastSpellCastAt[spellKey] = nowMs + minHealFriendCastGapMs

						return true
					end
				end
			end
		end
	end

	return false
end

function HelperHealFriend.init(pctx)
	ctx = pctx

	setupVocationThresholdControls()
	connectGameEvents()
	updateTargetingUi()
end

function HelperHealFriend.onShow()
	HelperHealFriend.applyVocationGate()
	syncPartyPlayers()
end

function HelperHealFriend.onHide()
	closePlayerListWindow()
	HelperHealFriend.destroyPlayerPriorityDragGhost()
end

function HelperHealFriend.terminate()
	closePlayerListWindow()
	HelperHealFriend.destroyPlayerPriorityDragGhost()
	cancelPartySync()
	cancelThresholdSave()
	disconnectGameEvents()

	lastSpellCastAt = {}
	customPlayers = {}
	activePartyPlayers = {}
end

function HelperHealFriend.collectConfig(config)
	config.healFriendClasses = config.healFriendClasses or {}

	for _, id in ipairs(HEAL_FRIEND_CHECK_IDS) do
		local w = ctx.getWidget(id)

		if w then
			config.healFriendClasses[id] = w:isChecked()
		end
	end

	config.healFriendPriorities = config.healFriendPriorities or {}

	for _, id in ipairs(HEAL_FRIEND_PRIORITY_IDS) do
		local w = ctx.getWidget(id)

		if w then
			config.healFriendPriorities[id] = w:getText()
		end
	end

	config.healFriendThresholds = config.healFriendThresholds or {}

	for _, id in ipairs(LEGACY_HEAL_FRIEND_THRESHOLD_IDS) do
		local w = ctx.getWidget(id)

		if w then
			config.healFriendThresholds[id] = tostring(clampThreshold(w:getText()))
		end
	end

	config.healFriendVocationThresholds = {}

	for _, id in ipairs(HEAL_FRIEND_VOCATION_THRESHOLD_IDS) do
		local w = ctx.getWidget(id)

		if w then
			config.healFriendVocationThresholds[id] = tostring(clampThreshold(w:getText()))
		end
	end

	config.healFriendConditions = config.healFriendConditions or {}

	for _, id in ipairs(HEAL_FRIEND_CONDITION_IDS) do
		local w = ctx.getWidget(id)

		if w and w.getCurrentOption then
			local opt = w:getCurrentOption()

			if type(opt) == "table" then
				opt = opt.text
			end

			config.healFriendConditions[id] = opt
		end
	end

	config.healFriendTargeting = {
		source = SOURCE_PARTY,
		players = sanitizeCustomPlayers(customPlayers)
	}
end

function HelperHealFriend.loadFromConfig(config)
	local classes = config.healFriendClasses or {}

	for _, id in ipairs(HEAL_FRIEND_CHECK_IDS) do
		local w = ctx.getWidget(id)

		if w and classes[id] ~= nil then
			w:setChecked(classes[id] == true)
		end
	end

	local priorities = config.healFriendPriorities or {}

	for _, id in ipairs(HEAL_FRIEND_PRIORITY_IDS) do
		local w = ctx.getWidget(id)

		if w and priorities[id] ~= nil then
			w:setText(tostring(priorities[id]))
		end
	end

	local thresholds = config.healFriendThresholds or {}

	for _, id in ipairs(LEGACY_HEAL_FRIEND_THRESHOLD_IDS) do
		local w = ctx.getWidget(id)

		if w and thresholds[id] ~= nil then
			w:setText(tostring(clampThreshold(thresholds[id])))
		end
	end

	local vocationThresholds = config.healFriendVocationThresholds or {}

	for panelIdx = 1, 3 do
		local legacyValue = thresholds["friendThresholdEdit" .. panelIdx] or THRESHOLD_DEFAULT

		for _, classKey in ipairs(CLASS_KEYS) do
			local id = vocationThresholdId(classKey, panelIdx)
			local w = ctx.getWidget(id)

			if w then
				w:setText(tostring(clampThreshold(vocationThresholds[id] or legacyValue)))
			end
		end
	end

	local conditions = config.healFriendConditions or {}

	for _, id in ipairs(HEAL_FRIEND_CONDITION_IDS) do
		local w = ctx.getWidget(id)

		if w and conditions[id] ~= nil and w.setCurrentOption then
			w:setCurrentOption(tostring(conditions[id]))
		end
	end

	local targeting = type(config.healFriendTargeting) == "table" and config.healFriendTargeting or {}

	customPlayers = sanitizeCustomPlayers(targeting.players)
	activePartyPlayers = {}

	HelperHealFriend.applyVocationGate()
	HelperHealFriend.refreshAllPrioritySteppers()
	refreshAllThresholdSteppers()
	syncPartyPlayers()
end

function HelperHealFriend.refreshLanguage()
	updateTargetingUi()

	if playerListWindow and not playerListWindow:isDestroyed() and ctx.applyWidgetLanguage then
		ctx.applyWidgetLanguage(playerListWindow)
	end
end

function HelperHealFriend:onEnableHealFriendChange(on)
	if on and not isAllowedVocation() then
		self:setChecked(false)

		if modules.game_textmessage then
			modules.game_textmessage.displayFailureMessage("Heal Friend is available only for Druid/ED and Monk/EM.")
		end
	end

	saveConfigIfReady()
end

function HelperHealFriend.onHealFriendClassToggle(_, _)
	saveConfigIfReady()
end
