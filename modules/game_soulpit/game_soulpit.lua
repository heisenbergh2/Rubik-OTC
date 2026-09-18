-- chunkname: @/game_soulpit/game_soulpit.lua

soulpitWindow = nil

local soulSealsPanel, creaturesList, searchEdit, showSoulSealOption, previewCreature, previewCreatureName, soulSealCreatureValue, fightButton
local currentSoulSealsBalance = 0
local SOUL_SEALS_BY_DIFFICULTY = {
	[0] = 10,
	20,
	30,
	40,
	50,
	60
}
local soulPitCreatureCache
local animusMasteriesSet = {}
local selectedSoulPitRow, selectedSoulPitRace, listBuildEvent
local SOULPIT_COLOR_EVEN = "#484848"
local SOULPIT_COLOR_ODD = "#414141"
local SOULPIT_COLOR_SELECTED = "#585858"
local SOULPIT_BATCH_SIZE = 36
local SOULPIT_FILTER_ALL = -1
local SOUL_SEALS_RESOURCE = 87

local function capitalizeWords(str)
	return (str or ""):gsub("(%a)([%w_']*)", function(first, rest)
		return first:upper() .. rest:lower()
	end)
end

local function formatNumberWithCommas(n)
	local s = tostring(n)
	local pos = string.len(s) % 3

	if pos == 0 then
		pos = 3
	end

	local t = s:sub(1, pos)

	for i = pos + 1, #s, 3 do
		t = t .. "," .. s:sub(i, i + 2)
	end

	return t
end

local function getSoulSealsRequired(difficulty)
	return SOUL_SEALS_BY_DIFFICULTY[tonumber(difficulty) or 0] or 10
end

local function applyCreaturePreview(creatureWidget, outfit, isSlotPreview)
	if not creatureWidget or not outfit then
		return
	end

	creatureWidget:setOutfit(outfit)

	if isSlotPreview then
		creatureWidget:setFixedCreatureSize(true)
	end

	local creature = creatureWidget:getCreature()

	if creature then
		creature:setStaticWalking(1000)
	end
end

local function updateFightButtonState()
	if not fightButton or fightButton:isDestroyed() then
		return
	end

	if not selectedSoulPitRace then
		fightButton:setEnabled(false)

		return
	end

	local required = getSoulSealsRequired(selectedSoulPitRace.difficulty)

	fightButton:setEnabled(required <= currentSoulSealsBalance)
end

local function updatePreviewSelection()
	local hasSelection = selectedSoulPitRace ~= nil

	if previewCreatureName and not previewCreatureName:isDestroyed() then
		if hasSelection then
			previewCreatureName:setText(capitalizeWords(selectedSoulPitRace.name))
			previewCreatureName:show()
		else
			previewCreatureName:hide()
		end
	end

	if previewCreature and not previewCreature:isDestroyed() then
		if hasSelection and selectedSoulPitRace.outfit then
			applyCreaturePreview(previewCreature, selectedSoulPitRace.outfit, true)
			previewCreature:show()
		else
			previewCreature:setOutfit({
				type = 0
			})
		end
	end

	if soulSealCreatureValue and not soulSealCreatureValue:isDestroyed() then
		if hasSelection then
			soulSealCreatureValue:setText(tostring(getSoulSealsRequired(selectedSoulPitRace.difficulty)))
		else
			soulSealCreatureValue:setText("0")
		end
	end

	updateFightButtonState()
end

local function updateSoulSealsBalance(balance)
	currentSoulSealsBalance = tonumber(balance) or 0

	if not soulSealsPanel or soulSealsPanel:isDestroyed() then
		updateFightButtonState()

		return
	end

	local valueLabel = soulSealsPanel:getChildById("value")

	if valueLabel then
		valueLabel:setText(formatNumberWithCommas(currentSoulSealsBalance))
	end

	updateFightButtonState()
end

local function refreshSoulSealsBalance()
	local player = g_game.getLocalPlayer()

	if not player then
		return
	end

	updateSoulSealsBalance(player:getResourceBalance(SOUL_SEALS_RESOURCE) or 0)
end

local function cacheWindowWidgets()
	if not soulpitWindow or soulpitWindow:isDestroyed() then
		return
	end

	soulSealsPanel = soulpitWindow:recursiveGetChildById("soulSealsPanel")
	creaturesList = soulpitWindow:recursiveGetChildById("creaturesList")
	searchEdit = soulpitWindow:recursiveGetChildById("search")
	showSoulSealOption = soulpitWindow:recursiveGetChildById("showSoulSealOption")
	previewCreature = soulpitWindow:recursiveGetChildById("creatureSprite")
	previewCreatureName = soulpitWindow:recursiveGetChildById("creatureName")
	soulSealCreatureValue = soulpitWindow:recursiveGetChildById("soulSealCreatureValue")
	fightButton = soulpitWindow:recursiveGetChildById("fightButton")
end

local function clearSoulPitSelection()
	if selectedSoulPitRow and not selectedSoulPitRow:isDestroyed() then
		selectedSoulPitRow:setBackgroundColor(selectedSoulPitRow.soulPitBaseColor or SOULPIT_COLOR_EVEN)
	end

	selectedSoulPitRow = nil
	selectedSoulPitRace = nil

	updatePreviewSelection()
end

local function buildAnimusMasteriesSet(animusMasteries)
	animusMasteriesSet = {}

	for _, raceId in ipairs(animusMasteries or {}) do
		animusMasteriesSet[raceId] = true
	end
end

local function buildSoulPitCreatureCache()
	local allRaces = g_things.getMonsterList()
	local filtered = {}

	for _, race in ipairs(allRaces) do
		if not race.boss and race.occurrence == 0 then
			filtered[#filtered + 1] = race
		end
	end

	table.sort(filtered, function(a, b)
		return a.name:lower() < b.name:lower()
	end)

	soulPitCreatureCache = filtered
end

local function getSoulPitCreaturesSorted()
	if not soulPitCreatureCache then
		buildSoulPitCreatureCache()
	end

	return soulPitCreatureCache
end

local function getDifficultyFilter()
	if not showSoulSealOption or showSoulSealOption:isDestroyed() then
		return nil
	end

	local index = showSoulSealOption:getCurrentIndex()

	if not index or index <= 1 then
		return nil
	end

	local option = showSoulSealOption:getCurrentOption()

	if option and option.data ~= nil and option.data >= 0 then
		return option.data
	end

	return index - 2
end

local function resetSoulPitFilters()
	if searchEdit and not searchEdit:isDestroyed() then
		searchEdit:setText("")
	end

	if showSoulSealOption and not showSoulSealOption:isDestroyed() then
		showSoulSealOption:setCurrentOptionByData(SOULPIT_FILTER_ALL, true)
	end
end

local function sortCreatureList(creatures, difficultyFilter)
	if difficultyFilter == nil then
		table.sort(creatures, function(a, b)
			return a.name:lower() < b.name:lower()
		end)

		return
	end

	table.sort(creatures, function(a, b)
		local difficultyA = tonumber(a.difficulty) or 0
		local difficultyB = tonumber(b.difficulty) or 0

		if difficultyA ~= difficultyB then
			return difficultyA < difficultyB
		end

		return a.name:lower() < b.name:lower()
	end)
end

local function cancelListBuild()
	if listBuildEvent then
		removeEvent(listBuildEvent)

		listBuildEvent = nil
	end
end

local function selectSoulPitRow(row, race)
	if selectedSoulPitRow and selectedSoulPitRow ~= row and not selectedSoulPitRow:isDestroyed() then
		selectedSoulPitRow:setBackgroundColor(selectedSoulPitRow.soulPitBaseColor or SOULPIT_COLOR_EVEN)
	end

	selectedSoulPitRow = row
	selectedSoulPitRace = race

	if row then
		row:setBackgroundColor(SOULPIT_COLOR_SELECTED)
	end

	updatePreviewSelection()
end

local function createSoulPitRow(list, race, rowIndex, hasSoulSeal)
	local row = g_ui.createWidget("SoulPitCreatureRow", list)

	if not row then
		return
	end

	local base = rowIndex % 2 == 0 and SOULPIT_COLOR_EVEN or SOULPIT_COLOR_ODD

	row.soulPitBaseColor = base
	row.soulPitRace = race

	row:setBackgroundColor(base)

	local sprite = row:getChildById("creatureSprite")

	if sprite and race.outfit then
		applyCreaturePreview(sprite, race.outfit, false)
	end

	local nameLabel = row:getChildById("creatureName")

	if nameLabel then
		nameLabel:setText(capitalizeWords(race.name))
	end

	local soulSealsRequiredLabel = row:getChildById("soulSealsRequired")

	if soulSealsRequiredLabel then
		soulSealsRequiredLabel:setText(tostring(getSoulSealsRequired(race.difficulty)))
	end

	function row.onClick()
		selectSoulPitRow(row, race)
	end
end

local function populateCreatureList(filterText)
	cancelListBuild()

	if not creaturesList or creaturesList:isDestroyed() then
		return
	end

	if selectedSoulPitRow and not selectedSoulPitRow:isDestroyed() then
		selectedSoulPitRow:setBackgroundColor(selectedSoulPitRow.soulPitBaseColor or SOULPIT_COLOR_EVEN)
	end

	selectedSoulPitRow = nil
	selectedSoulPitRace = nil

	creaturesList:destroyChildren()
	updatePreviewSelection()

	local creatures = getSoulPitCreaturesSorted()
	local lowerFilter = filterText and filterText:lower() or ""
	local difficultyFilter = getDifficultyFilter()
	local toCreate = {}

	for _, race in ipairs(creatures) do
		local matchesSearch = lowerFilter == "" or race.name:lower():find(lowerFilter, 1, true)
		local matchesDifficulty = difficultyFilter == nil or tonumber(race.difficulty) == difficultyFilter

		if matchesSearch and matchesDifficulty then
			toCreate[#toCreate + 1] = race
		end
	end

	sortCreatureList(toCreate, difficultyFilter)

	local idx = 1
	local total = #toCreate

	local function createNextBatch()
		listBuildEvent = nil

		if not creaturesList or creaturesList:isDestroyed() then
			return
		end

		local endIdx = math.min(idx + SOULPIT_BATCH_SIZE - 1, total)

		for i = idx, endIdx do
			local race = toCreate[i]

			createSoulPitRow(creaturesList, race, i - 1, animusMasteriesSet[race.raceId] == true)
		end

		idx = endIdx + 1

		if idx <= total then
			listBuildEvent = scheduleEvent(createNextBatch, 0)
		end
	end

	createNextBatch()
end

function filterList(filterText)
	populateCreatureList(filterText)
end

function clearSearch()
	if searchEdit and not searchEdit:isDestroyed() then
		searchEdit:setText("")
	end

	populateCreatureList("")
end

function onShowSoulSealOptionChange(combo)
	local text = ""

	if searchEdit and not searchEdit:isDestroyed() then
		text = searchEdit:getText()
	end

	populateCreatureList(text)
end

function fight()
	if not selectedSoulPitRace then
		return
	end

	sendSoulSealSelectCreature(selectedSoulPitRace.raceId)
end

function init()
	g_ui.importStyle("game_soulpit")
	connect(g_game, {
		onGameEnd = destroyDialog,
		onSoulPitModal = onSoulPitModal
	})
end

function terminate()
	disconnect(g_game, {
		onGameEnd = destroyDialog,
		onSoulPitModal = onSoulPitModal
	})
	destroyDialog()
end

function destroyDialog()
	cancelListBuild()

	if soulpitWindow then
		g_modalManager.hide(soulpitWindow)
		soulpitWindow:destroy()

		soulpitWindow = nil
	end

	soulSealsPanel = nil
	creaturesList = nil
	searchEdit = nil
	showSoulSealOption = nil
	previewCreature = nil
	previewCreatureName = nil
	soulSealCreatureValue = nil
	fightButton = nil
	selectedSoulPitRow = nil
	selectedSoulPitRace = nil
end

function hide()
	if soulpitWindow and not soulpitWindow:isDestroyed() then
		g_modalManager.hide(soulpitWindow)
		soulpitWindow:hide()
	end
end

function onSoulPitModal(animusMasteries)
	if soulpitWindow and not soulpitWindow:isDestroyed() then
		soulpitWindow:show()
	else
		soulpitWindow = g_ui.createWidget("SoulPitWindow", rootWidget)
	end

	cacheWindowWidgets()
	buildAnimusMasteriesSet(animusMasteries)
	resetSoulPitFilters()
	populateCreatureList("")
	refreshSoulSealsBalance()
	scheduleEvent(refreshSoulSealsBalance, 0)
	updatePreviewSelection()
	soulpitWindow:raise()
	soulpitWindow:focus()
	g_modalManager.show(soulpitWindow)
end

function sendSoulSealSelectCreature(raceId)
	g_game.sendSoulSealSelectCreature(raceId)
	hide()
end
